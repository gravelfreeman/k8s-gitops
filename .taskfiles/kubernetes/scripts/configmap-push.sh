#!/usr/bin/env bash

set -euo pipefail

app="$1"
cd "$(git rev-parse --show-toplevel)"
app_dir="$(find kubernetes/apps -type f -path "*/${app}/app/kustomization.yaml" -print -quit)"

test -n "$app_dir"

app_dir="${app_dir%/kustomization.yaml}"
domain="${app_dir#kubernetes/apps/}"
domain="${domain%%/*}"

while IFS=$'\t' read -r key value; do
  [ -n "$key" ] || continue
  printf -v "$key" '%s' "$(printf '%s' "$value" | base64 --decode)"
  export "$key"
done < <(
  kubectl get secret flux-common -n flux-system -o json \
    | jq -r '.data // {} | to_entries[] | [.key, .value] | @tsv'
)

export APP="$app" domain

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

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

kustomize build "$app_dir" \
  | flux envsubst --strict \
  | yq eval-all --output-format=json \
      'select(.kind == "ConfigMap" and (.data != null or .binaryData != null))' - \
  | jq -s . > "$tmp_dir/configmaps.json"

changed_keys="$(
  while IFS= read -r path; do
    case "$path" in
      "$app_dir"/config/*) basename "$path" ;;
    esac
  done <<< "$changed_files" \
    | jq -Rsc 'split("\n") | map(select(length > 0)) | unique'
)"

if [ "$changed_keys" != "[]" ]; then
  jq --argjson keys "$changed_keys" \
    'map(select(([((.data // {}) | keys[]), ((.binaryData // {}) | keys[])] | any(.[]; . as $key | ($keys | index($key))))))' \
    "$tmp_dir/configmaps.json" > "$tmp_dir/changed-configmaps.json"
else
  cp "$tmp_dir/configmaps.json" "$tmp_dir/changed-configmaps.json"
fi

test "$(jq 'length' "$tmp_dir/changed-configmaps.json")" -gt 0

while IFS= read -r configmap; do
  local_name="$(jq -r '.metadata.name' <<< "$configmap")"
  base_name="$(sed -E 's/-[a-z0-9]{10}$//' <<< "$local_name")"
  live_name="$(
    kubectl get deployment,statefulset,daemonset -n "$app" \
      -l "app.kubernetes.io/name=$app" -o json \
      | jq -r --arg base "$base_name" '
          [.items[].spec.template.spec.volumes[]?.configMap.name?
            | select(type == "string")
            | select(. == $base or startswith($base + "-"))]
          | unique | .[0] // empty
        '
  )"

  if [ -z "$live_name" ]; then
    live_name="$(
      kubectl get configmaps -n "$app" -o json \
        | jq -r --arg base "$base_name" '
            [.items[].metadata.name
              | select(. == $base or startswith($base + "-"))]
            | sort | .[0] // empty
          '
    )"
  fi

  test -n "$live_name"

  jq --arg name "$live_name" '
      .metadata.name = $name
      | del(.metadata.creationTimestamp, .metadata.managedFields,
            .metadata.resourceVersion, .metadata.uid)
    ' <<< "$configmap" \
    | kubectl apply --namespace "$app" --server-side --force-conflicts --field-manager=task-configmap -f -
done < <(jq -c '.[]' "$tmp_dir/changed-configmaps.json")

kubectl get deployment,statefulset,daemonset -n "$app" \
  -l "app.kubernetes.io/name=$app" -o name \
  | while IFS= read -r workload; do
      kubectl rollout restart -n "$app" "$workload"
      kubectl rollout status -n "$app" "$workload" --timeout=2m
    done
