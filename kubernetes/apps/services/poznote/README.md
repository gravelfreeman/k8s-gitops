# Poznote

Poznote's official rootless image runs as UID/GID `1000`. The data PVC must be owned by `1000:1000`; newly provisioned or restored volumes may require a one-time permission fix with `chown -R 1000:1000 /data`. The namespace uses Pod Security `baseline` to allow this temporary maintenance pod.

## Fix PVC permissions

Stop Poznote, mount the PVC in a temporary root pod, then restart the app:

```bash
kubectl -n poznote patch helmrelease poznote --type=merge -p '{"spec":{"suspend":true}}'
kubectl -n poznote scale deployment poznote --replicas=0
kubectl -n poznote wait --for=delete pod -l app.kubernetes.io/name=poznote --timeout=120s
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
kubectl -n poznote scale deployment poznote --replicas=1
kubectl -n poznote patch helmrelease poznote --type=merge -p '{"spec":{"suspend":false}}'
```
