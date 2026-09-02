[doc("Boostrap everything from zero")]
full:
    just bootstrap::cluster
    just bootstrap::cilium
    just secrets::restore_sealed_secrets_private_key
    just bootstrap::sealed_secrets

[doc("Bootstrap VMs and talos cluster")]
[working-directory('../infrastructure')]
cluster:
    just tf::init
    just tf::apply -auto-approve
    just bootstrap::create_cluster_config

[doc("Create talasconfig and kubeconfig")]
[working-directory('../infrastructure')]
create_cluster_config:
    tofu output -raw talosconfig > talosconfig.yaml
    tofu output -raw kubeconfig > kubeconfig.yaml
    just secrets::encrypt_cluster_config

[doc("Bootstrap Cilium")]
[working-directory('../gitops')]
cilium: wait_for_api
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
    helm install cilium \
        --repo https://helm.cilium.io/ \
        cilium \
        --namespace kube-system \
        --version 1.20.1 \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost=172.20.0.20 \
        --set k8sServicePort=6443 \
        --set l2announcements.enabled=true \
        --set externalIPs.enabled=true \
        --set gatewayAPI.enabled=true \
        --set ipam.mode=kubernetes \
        --set operator.replicas=1 \
        --set securityContext.privileged=true
    kubectl rollout status daemonset/cilium -n kube-system
    kubectl apply -f bootstrap/cilium_config.yaml
    talosctl health -n 172.20.0.21 --wait-timeout 10m

[doc("Install sealed secrets controller")]
sealed_secrets:
    helm install sealed-secrets \
        --repo https://bitnami.github.io/sealed-secrets \
        sealed-secrets \
        --version 2.19.3 \
        --namespace sealed-secrets \
        --create-namespace \
        --set fullnameOverride=sealed-secrets-controller
    # Wait for it to deploy
    kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets

[private]
wait_for_api:
    until kubectl get nodes 2>/dev/null | grep -q "NotReady\|Ready"; do sleep 5; done

