# Task

Run pod `run-pod-in-namespace-pod` in namesapce `run-pod-in-namespace-ns`.

# Solution

Create namespace:
```sh
kubectl create ns run-pod-in-namespace-ns
```

Create pod in namespace:
```sh
kubectl apply -f - << 'END'
apiVersion: v1
kind: Pod
metadata:
  namespace: run-pod-in-namespace-ns
  name: run-pod-in-namespace-pod
spec:
  restartPolicy: Never
  containers:
  - name: c1
    image: alpine
    command: ['sh', '-c', 'sleep 10']
END
```

Confirm:
```sh
kubectl get pods -n run-pod-in-namespace-ns
```
```text
NAME                       READY   STATUS    RESTARTS   AGE
run-pod-in-namespace-pod   1/1     Running   0          13s
```
