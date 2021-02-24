## Task

Run pod named `run-pod-once` once. Pod should sleep for 10 seconds and exit successfully.

## Solution

As pod:
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

As job:
```sh
kubectl apply -f - << 'END'
apiVersion: batch/v1
kind: Job
metadata:
  name: run-pod-once-job
spec:
  template:
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
