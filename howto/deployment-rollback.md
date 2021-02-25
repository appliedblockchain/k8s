## Task

Perform deployment rollback.

## Solution

We'll use host path, create directory on every node:
```sh
for vm in k1 k2 k3; do
  ssh -T $vm << END
    sudo mkdir -p /pv/deployment-rollback
    echo 'hi from $vm!' | sudo tee /pv/deployment-rollback/index.html
END
done
```

Create pv:
```sh
ssh -T k1 << 'END'
kubectl apply -f - << 'END_'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-deployment-rollback
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/pv/deployment-rollback"
END_
END
```

Create claim:
```sh
ssh -T k1 << 'END'
kubectl apply -f - << 'END_'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-deployment-rollback
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
END_
END
```

```sh
kubectl apply -f - << 'END'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-rollback
  labels:
    app: deployment-rollback
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deployment-rollback
  template:
    metadata:
      labels:
        app: deployment-rollback
    spec:
      volumes:
        - name: volume
          persistentVolumeClaim:
            claimName: pvc-deployment-rollback
      containers:
        - name: server
          image: node
          command: [ 'npx', '-y', 'serve', '--', '-l', '80', '/usr/share/public' ]
          ports:
            - containerPort: 80
              name: "http-server"
          volumeMounts:
            - mountPath: "/usr/share/public"
              name: volume
END
```

Create service:
```sh
kubectl apply -f - << 'END'
apiVersion: v1
kind: Service
metadata:
  name: service-deployment-rollback
spec:
  selector:
    app: deployment-rollback
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
END
```

Make sure service is available:
```sh
ssh k1 curl -vv http://localhost:8001/api/v1/namespaces/default/services/service-deployment-rollback/proxy/
```

Assuming pod is scheduled on k3:
```sh
ssh k1 sudo halt
```

Service should be available, deployment should reschedule pod onto one of available nodes (but it doesn't?).
