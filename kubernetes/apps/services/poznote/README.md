# Poznote

Poznote's official rootless image runs as UID/GID `1000`. The data PVC must be owned by `1000:1000`; newly provisioned or restored volumes may require a one-time permission fix with `chown -R 1000:1000 /data`. The namespace normally uses Pod Security `restricted`; temporarily switch it to `baseline` for the maintenance pod.

**Error before the fix:**
```text
Poznote Initialization Script - Setting up data directory...
ERROR: /var/www/html/data is owned by uid 0, but this container is running as uid 1000 (non-root).
Running rootlessly, this container cannot chown a mounted volume it does not already own.
Fix ownership on the host before starting the container, e.g.:
    sudo chown -R 1000:1000 ./data
stream closed: EOF for poznote/poznote-7f678c59b-89tdw (app)
```

## Fix PVC permissions

Stop Poznote, mount the PVC in a temporary root pod, then restart the app:

```bash
kubectl -n poznote patch helmrelease poznote --type=merge -p '{"spec":{"suspend":true}}'
kubectl -n poznote scale deployment poznote --replicas=0
kubectl -n poznote wait --for=delete pod -l app.kubernetes.io/name=poznote --timeout=120s
kubectl label namespace poznote pod-security.kubernetes.io/enforce=baseline --overwrite
```

```bash
kubectl -n poznote apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: poznote-fix-permissions
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: fix
      image: alpine:3.22
      command: ["sh", "-c", "chown -R 1000:1000 /data"]
      securityContext:
        runAsUser: 0
        runAsGroup: 0
        runAsNonRoot: false
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
          add: ["CHOWN"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: poznote-data
EOF

kubectl -n poznote wait --for=jsonpath='{.status.phase}'=Succeeded pod/poznote-fix-permissions --timeout=120s
kubectl -n poznote delete pod poznote-fix-permissions
kubectl label namespace poznote pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl -n poznote scale deployment poznote --replicas=1
kubectl -n poznote patch helmrelease poznote --type=merge -p '{"spec":{"suspend":false}}'
```
