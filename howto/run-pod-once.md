
## Task

Run pod named `run-pod-once` once. Pod should sleep for 10 seconds and exit successfully.

## Solution

```sh
kubectl apply -f - << 'END'
apiVersion: v1
kind: Pod
metadata:
  name: run-pod-once
spec:
  restartPolicy: Never
  containers:
  - name: c1
    image: alpine
    command: ['sh', '-c', 'sleep 10']
END
```
