# K9s

Run [k9s](https://k9scli.io):
```sh
ssh -tt k1 'docker run --rm -it -v ~/.kube/config:/root/.kube/config quay.io/derailed/k9s'
```
