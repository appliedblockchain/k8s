# Task

Create persisted volume and claim it in pod.

# Solution

We'll use host path, create directory on every node:
```sh
for vm in k1 k2 k3; do
  ssh $vm sudo mkdir -p /pv/1
done
```

Create pv:
```sh
ssh -T k1 << 'END'
kubectl apply -f - << 'END_'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/pv/1"
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
  name: pvc1
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

Create pod:
```sh
ssh -T k1 << 'END'
kubectl apply -f - << 'END_'
apiVersion: v1
kind: Pod
metadata:
  name: claim-volume-pod
  labels:
    app: claim-volume
spec:
  volumes:
    - name: vol1
      persistentVolumeClaim:
        claimName: pvc1
  containers:
    - name: server
      image: node
      command: [ 'npx', '-y', 'serve', '--', '-l', '80', '/usr/share/public' ]
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/public"
          name: vol1
END_
END
```

Create index.html:
```sh
for vm in k1 k2 k3; do
  ssh $vm "echo 'hi from $vm!' | sudo tee -a /pv/1/index.html"
done
```

Confirm by using shell on pod:
```sh
kubectl exec -ti claim-volume-pod -- /bin/bash

curl http://localhost
# hi
```

Open proxy:
```sh
kubectl proxy
```

Tunnel proxy to macOS:
```sh
ssh -L 8001:localhost:8001 k1
```

Create service:
```sh
kubectl apply -f - << 'END'
apiVersion: v1
kind: Service
metadata:
  name: claim-volume-srv
spec:
  selector:
    app: claim-volume
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
END
```

From macOS use curl or browser:
```sh
curl -vv http://localhost:8001/api/v1/namespaces/default/services/claim-volume-srv/proxy/
```
