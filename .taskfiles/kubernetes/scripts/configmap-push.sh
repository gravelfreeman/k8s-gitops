#!/usr/bin/env bash

set -euo pipefail

app="$1"
cd "$(git rev-parse --show-toplevel)"

app_dir="$(find kubernetes/apps -type f -path "*/${app}/ks.yaml" -printf '%h\n' \
  | awk 'length($0) > max { max = length($0); path = $0 } END { print path }')"
if [ -z "$app_dir" ]; then
  printf 'No app directory found for %s\n' "$app" >&2
  exit 1
fi

domain="${app_dir#kubernetes/apps/}"
domain="${domain%%/*}"
changed_files="$(
  {
    git diff --name-only HEAD -- "$app_dir"
    git ls-files --others --exclude-standard -- "$app_dir"
  } | sort -u
)"
if [ -z "$changed_files" ]; then
  printf 'No local changes found for %s\n' "$app" >&2
  exit 1
fi

while IFS=$'\t' read -r key value; do
  [ -n "$key" ] || continue
  printf -v "$key" '%s' "$(printf '%s' "$value" | base64 --decode)"
  export "$key"
done < <(kubectl get secret flux-common -n flux-system -o json \
  | jq -r '.data // {} | to_entries[] | [.key, .value] | @tsv')
export APP="$app" domain

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
printf '[]\n' > "$tmp_dir/configmaps.json"
kustomizations="$(find "$app_dir" -type f \
  \( -name kustomization.yaml -o -name kustomization.yml -o -name Kustomization \) \
  -print | sort)"
if [ -z "$kustomizations" ]; then
  printf 'No Kustomizations found under %s\n' "$app_dir" >&2
  exit 1
fi

while IFS= read -r file; do
  kustomize build "${file%/*}" | flux envsubst --strict \
    | yq eval-all --output-format=json \
        'select(.kind == "ConfigMap" and (.data != null or .binaryData != null))' - \
    | jq -s . > "$tmp_dir/current.json"
  jq -s 'add | unique_by(.metadata.name)' "$tmp_dir/configmaps.json" \
    "$tmp_dir/current.json" > "$tmp_dir/merged.json"
  mv "$tmp_dir/merged.json" "$tmp_dir/configmaps.json"
done <<< "$kustomizations"

changed_keys="$(while IFS= read -r file; do basename "$file"; done <<< "$changed_files" \
  | jq -Rsc 'split("\n") | map(select(length > 0)) | unique')"
changed_names="$(while IFS= read -r file; do
  case "$file" in
    *.yaml|*.yml|*.json) yq eval-all -r 'select(.kind == "ConfigMap") | .metadata.name // ""' "$file" 2>/dev/null || true ;;
  esac
done <<< "$changed_files" | jq -Rsc 'split("\n") | map(select(length > 0)) | unique')"
jq --argjson keys "$changed_keys" --argjson names "$changed_names" '
  map(select(
    (((.data // {}) | keys) + ((.binaryData // {}) | keys)
      | any(. as $key | $keys | index($key)))
    or ((.metadata.name | sub("-[a-z0-9]{10}$"; "")) as $base
      | any($names[]; . == $base))
  ))
' "$tmp_dir/configmaps.json" > "$tmp_dir/changed.json"
if [ "$(jq 'length' "$tmp_dir/changed.json")" -eq 0 ]; then
  cp "$tmp_dir/configmaps.json" "$tmp_dir/changed.json"
fi
if [ "$(jq 'length' "$tmp_dir/changed.json")" -eq 0 ]; then
  printf 'No ConfigMaps found under %s\n' "$app_dir" >&2
  exit 1
fi

while IFS= read -r configmap; do
  local_name="$(jq -r '.metadata.name' <<< "$configmap")"
  base_name="$(sed -E 's/-[a-z0-9]{10}$//' <<< "$local_name")"
  live_name="$(kubectl get deployment,statefulset,daemonset -n "$app" \
    -l "app.kubernetes.io/name=$app" -o json \
    | jq -r --arg base "$base_name" '
        [.items[].spec.template.spec.volumes[]?.configMap.name?
          | select(type == "string") | select(. == $base or startswith($base + "-"))]
        | unique | .[0] // empty')"
  if [ -z "$live_name" ]; then
    live_name="$(kubectl get configmaps -n "$app" -o json \
      | jq -r --arg base "$base_name" '
          [.items[].metadata.name | select(. == $base or startswith($base + "-"))]
          | sort | .[0] // empty')"
  fi
  if [ -z "$live_name" ]; then
    printf 'Could not find live ConfigMap matching %s in namespace %s\n' "$base_name" "$app" >&2
    exit 1
  fi

  jq --arg name "$live_name" '
    .metadata.name = $name
    | del(.metadata.creationTimestamp, .metadata.managedFields, .metadata.resourceVersion, .metadata.uid)
  ' <<< "$configmap" \
    | kubectl apply --namespace "$app" --server-side --force-conflicts --field-manager=task-configmap -f -
done < <(jq -c '.[]' "$tmp_dir/changed.json")

kubectl get deployment,statefulset,daemonset -n "$app" \
  -l "app.kubernetes.io/name=$app" -o name \
  | while IFS= read -r workload; do
      kind="$(kubectl get -n "$app" "$workload" -o json | jq -r '.kind')"
      if [ "$kind" = Deployment ]; then
        workload_json="$(kubectl get -n "$app" "$workload" -o json)"
        selector="$(jq -r '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")' <<< "$workload_json")"
        replicas="$(jq -r '.spec.replicas // 1' <<< "$workload_json")"
        pods="$(kubectl get pods -n "$app" -l "$selector" -o name)"
        if [ -z "$pods" ]; then
          printf 'No pods found for %s in namespace %s\n' "$workload" "$app" >&2
          exit 1
        fi
        while IFS= read -r pod; do
          kubectl delete -n "$app" "$pod"
          for ((attempt = 0; attempt < 120; attempt++)); do
            ready="$(kubectl get pods -n "$app" -l "$selector" -o json \
              | jq '[.items[] | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))] | length')"
            [ "$ready" -ge "$replicas" ] && break
            sleep 1
          done
          if [ "$ready" -lt "$replicas" ]; then
            printf 'Timed out waiting for %s ready pods for %s\n' "$replicas" "$workload" >&2
            exit 1
          fi
        done <<< "$pods"
      else
        kubectl rollout restart -n "$app" "$workload"
        kubectl rollout status -n "$app" "$workload" --timeout=2m
      fi
    done
