## Task

Reset cluster to new pod network cidr `10.234.0.0/16` on flannel.

## Solution

```sh

# Reset cluster
for vm in k1 k2 k3; do
  ssh $vm sudo kubeadm reset -f
done

ssh -T k1 << 'END'

  # Initialise cluster with new cidr:
  sudo kubeadm init --pod-network-cidr 10.234.0.0/16

  # Drop `--port=0`:
  for name in controller-manager scheduler; do
    sudo sed -i '/--port=0/d' /etc/kubernetes/manifests/kube-$name.yaml
  done

  # Update kube config:
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Apply flannel:
  for action in delete apply; do
    kubectl $action -f https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel.yml
  done

  # Recreate network (bug https://github.com/kubernetes/kubernetes/issues/39557):
  for vm in k1 k2 k3; do
    ssh $vm sudo ip link set cni0 down
    ssh $vm sudo brctl delbr cni0
  done

END

# Rejoin cluster:
ssh -T k1 << 'END' | pbcopy
  sudo kubeadm token create --print-join-command
END
for vm in k2 k3; do
  ssh $vm "sudo $(pbpaste)"
done
```

Confirm by [running pod](./run-pod-once.md) and checking its ip:
```sh
ssh k1 kubectl get pod run-pod-once -o jsonpath='{.status.podIP}'
```
```text
10.234.1.70
```
