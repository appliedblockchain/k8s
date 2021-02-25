# Dashboard

Deploy k8s dashboard:
```
ssh k1 kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
```

Create service account:
```sh
cat << 'END' | ssh k1 kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
END
```

Create cluster role binding:
```sh
cat << 'END' | ssh k1 kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
END
```

Start proxy on k1:
```sh
ssh k1 kubectl proxy
```

On macOS host, tunnel port 8001 to k1:
```sh
ssh -L 8001:localhost:8001 k1
```

On macOS navigate to http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login and paste token from clipboard.

Copy bearer token to clipboard:
```sh
cat << 'END' | ssh -T k1 | pbcopy
  kubectl -n kubernetes-dashboard get secret \
    $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
END
```

Login.

## Teardown

```sh
cat << 'END' | ssh -T k1
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl -n kubernetes-dashboard delete serviceaccount admin-user
kubectl -n kubernetes-dashboard delete clusterrolebinding admin-user
END
```
