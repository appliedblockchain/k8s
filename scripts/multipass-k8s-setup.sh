#!/usr/bin/env bash

# Installation:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/appliedblockchain/k8s/HEAD/scripts/multipass-k8s-setup.sh)"
#

set -Eeuo pipefail

vms="k1 k2 k3"

echo "will delete $vms if they exist"
for vm in $vms; do
  multipass stop $vm 2> /dev/null || echo "didn't stop $vm"
  multipass delete $vm 2> /dev/null || echo "didn't delete $vm"
done
multipass purge

echo "will delete known hosts for $vms if they exist"
for vm in $vms; do
  ssh-keygen -R $vm
done

echo "will launch $vms"
multipass launch --name k1 --mem 2G --cpus 2 xenial
multipass launch --name k2 --mem 1G --cpus 1 xenial
multipass launch --name k3 --mem 1G --cpus 1 xenial

echo "will disable welcome messages"
for vm in $vms; do
  multipass shell $vm << 'END'
    sudo chmod -x /etc/update-motd.d/*
END
done

if [ -f ~/.ssh/id_rsa.pub ]; then
  echo "will copy ssh id"
  for vm in $vms; do
    cat ~/.ssh/id_rsa.pub | pbcopy
    multipass shell $vm << END
      if [ ! -d ~/.ssh ]; then
        mkdir ~/.ssh
        chmod 0700 ~/.ssh
      fi
      echo "$(pbpaste)" >> ~/.ssh/authorized_keys
      chmod 0600 ~/.ssh/authorized_keys
END
    # ssh -o StrictHostKeyChecking=accept-new $vm
  done
fi

echo "will add apt sources"
for vm in $vms; do
  multipass shell $vm << 'END'

    # Add the encryption key for the packages:
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    # Add apt source:
    cat << END_ | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
END_

END
done

echo "will install"
for vm in $vms; do
  multipass shell $vm << 'END'

    # Update packages:
    sudo apt-get update
    sudo apt-get upgrade -y

    # Install docker and k8s:
    sudo apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni

    # Add user to docker group to run docker command without sudo:
    sudo usermod -aG docker ${USER}

    # Start docker:
    sudo systemctl start docker

    # Autostart docker:
    sudo systemctl enable docker

END
done

echo "will initialise container"
multipass shell k1 << 'END'

  # Initialise container:
  sudo kubeadm init --pod-network-cidr 10.244.0.0/16

  # Make kubectl available to the current user:
  mkdir -p $HOME/.kube
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Drop --port=0:
  for name in /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml; do
    sudo sed -i '/--port=0/d' $name
  done

  # Install flannel:
  kubectl apply -f https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel.yml

  # Setup k alias and bash completion:
  echo 'source <(kubectl completion bash)' >> ~/.bashrc
  echo 'alias k=kubectl' >> ~/.bashrc
  echo 'complete -F __start_kubectl k' >> ~/.bashrc

END

echo "will join cluster"
multipass shell k1 << 'END' | pbcopy
  sudo kubeadm token create --print-join-command
END

for vm in k2 k3; do
  multipass shell $vm << END
    sudo $(pbpaste)
END
done
