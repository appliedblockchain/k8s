# Multipass

[Multipass](https://multipass.run) runs Ubuntu based fully virtualised machines (as opposed to containers).

We'll use multipass to spawn 3 VMs from macOS host machine:
1. `k1` – as k8s master
2. `k2` – k8s worker
3. `k3` - k8s worker

Install multipass on macOS:
```sh
brew install multipass
```

Launch 3x VMs. K8s master requires 2 CPUs and 2 GB of RAM, workers can work on 1 cpu and 1 GB of RAM.
We're using Ubuntu Xenial (16.x) because Google provides APT sources for this version:
```sh
multipass launch --name k1 --mem 2G --cpus 2 xenial
multipass launch --name k2 --mem 1G --cpus 1 xenial
multipass launch --name k3 --mem 1G --cpus 1 xenial
```

At any point, in order to tear everything down before recreating everything from scratch:
```sh
for vm in k1 k2 k3; do
  multipass stop $vm
  multipass delete $vm
done
multipass purge
```

Add VMs' IP addresses to macOS `/etc/hosts` so it's easier to use:
```sh
multipass ls
```
```text
Name                    State             IPv4             Image
k1                      Running           192.168.64.6     Ubuntu 16.04 LTS
k2                      Running           192.168.64.7     Ubuntu 16.04 LTS
k3                      Running           192.168.64.8     Ubuntu 16.04 LTS
```
```sh
sudo nano /etc/hosts
```
```text
...
192.168.64.6 k1
192.168.64.7 k2
192.168.64.8 k3
```

Open shell to k1:
```sh
multipass shell k1
```

Authorise your ssh identity to access this host without password:
```sh
mkdir -p ~/.ssh
chmod 0700 ~/.ssh
cat << 'END' >> ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAsPTk9WfSLv1NDdLgW9RsDBkc65wD65kUgJljTheFYSpbcGc6I5Ijmwkqn59IjgPZjebFMINGb5UmBzNVie6GTGR7hnMSSbqinymrNQl97gbdPTD+F77+N1ta2NP+IxvFGQ+mO0wnSa7nVKCYO8fK/EC2thB9bIA1KWXo2IXot0U= rsa-key-20050514
END
chmod 0600 ~/.ssh/authorized_keys
```

Repeat above for k2 and k3.

Use default `ubuntu` username for those hosts:
```sh
cat << 'END' >> ~/.ssh/config
Host k1
  User ubuntu

Host k2
  User ubuntu

Host k3
  User ubuntu
END
```

Make sure we don't have legacy known host entries by deleting them:
```sh
for vm in k1 k2 k3; do
  ssh-keygen -R $vm
done
```

Confirm login works without username and password from macOS host:
```sh
for vm in k1 k2 k3; do
  ssh $vm hostname
done
```

Disable welcome message:
```sh
for vm in k1 k2 k3; do
  ssh $vm 'sudo chmod -x /etc/update-motd.d/*'
done
```

Update system, install docker and k8s:
```sh
for vm in k1 k2 k3; do

  # Update system:
  ssh $vm sudo apt-get update
  ssh $vm sudo apt-get -y upgrade

  # Install docker:
  ssh $vm sudo apt-get install -y docker.io

  # Start docker:
  ssh $vm sudo systemctl start docker

  # Automatically start docker after boot:
  ssh $vm sudo systemctl enable docker

done
```

Add ubuntu user to docker group so docker command can be run without sudo:
```sh
for vm in k1 k2 k3; do
  ssh $vm 'sudo usermod -aG docker ${USER}'
done
```

Confirm docker command can be run without sudo:
```sh
for vm in k1 k2 k3; do
  ssh $vm docker ps
done
```

Install k8s:
```sh
for vm in k1 k2 k3; do

  # Add the encryption key for the packages:
  ssh $vm 'curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -'

  # Add apt source:
  ssh $vm 'cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'

  # Install k8s:
  ssh $vm sudo apt-get update
  ssh $vm sudo apt-get upgrade -y
  ssh $vm sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni

done
```

Initialise head node:
```sh
ssh k1 sudo kubeadm init \
  --pod-network-cidr 10.244.0.0/16 \
  --apiserver-advertise-address 192.168.64.6 \
  --apiserver-cert-extra-sans k1
```

Join k2 and k3 to the cluster (token and cert hash will be shown at the end of above step):
```sh
for vm in k2 k3; do
  ssh $vm sudo kubeadm join \
    192.168.64.6:6443 \
    --token r1kywm.ko46o1ijioc6brno \
    --discovery-token-ca-cert-hash sha256:965ffc97102f0a729fcf1b02d0f11b355335d7105f718def96aaf2c34a000561
done
```

Make kubectl available to ubuntu user on k1:
```sh
ssh -T k1 << 'END'
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
END
```

Comment out `--port: 0` part in the following files on k1:
```text
/etc/kubernetes/manifests/kube-controller-manager.yaml
/etc/kubernetes/manifests/kube-scheduler.yaml
```

Use flannel for cluster networking:
```sh
ssh k1 'curl https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel.yml > kube-flannel.yaml'
ssh k1 kubectl apply -f kube-flannel.yaml
```

Eventually cluster should be ready:

```sh
ssh k1 kubectl get componentstatuses
```
```text
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
```

```sh
ssh k1 kubectl get nodes
```text
NAME   STATUS   ROLES                  AGE   VERSION
k1     Ready    control-plane,master   73m   v1.20.4
k2     Ready    <none>                 72m   v1.20.4
k3     Ready    <none>                 72m   v1.20.4
```

```sh
ssh k1 kubectl get pods -n kube-system
```
```text
NAME                         READY   STATUS    RESTARTS   AGE
coredns-74ff55c5b-f9gms      1/1     Running   0          75m
coredns-74ff55c5b-j5blk      1/1     Running   0          75m
etcd-k1                      1/1     Running   0          76m
kube-apiserver-k1            1/1     Running   0          76m
kube-controller-manager-k1   1/1     Running   0          6m35s
kube-flannel-ds-8h22g        1/1     Running   0          3m28s
kube-flannel-ds-8sgqw        1/1     Running   0          3m28s
kube-flannel-ds-xh9cq        1/1     Running   0          3m28s
kube-proxy-bxdpg             1/1     Running   0          75m
kube-proxy-pchm9             1/1     Running   0          74m
kube-proxy-tddss             1/1     Running   0          74m
kube-scheduler-k1            1/1     Running   0          6m23s
```

Tear everything down:
```sh
for vm in k1 k2 k3; do
  multipass stop $vm
  multipass delete $vm
done
multipass purge
```
...and do it again :)
