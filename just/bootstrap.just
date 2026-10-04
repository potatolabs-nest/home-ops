[doc("Boostrap everything from zero")]
full:
    just bootstrap::cluster
    just bootstrap::cilium
    just secrets::restore_sealed_secrets_private_key
    just bootstrap::sealed_secrets
    just bootstrap::argocd

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
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml
    helm install cilium \
        --repo https://helm.cilium.io/ \
        cilium \
        --namespace kube-system \
        --version 1.20.2 \
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

[doc("Bootstrap ArgoCD")]
[working-directory('../gitops')]
argocd:
    helm install argocd \
        --repo https://argoproj.github.io/argo-helm \
        argo-cd \
        --namespace argocd \
        --create-namespace \
        --version 10.6.4 \
        --set configs.secret.createSecret=false
    # We don't let ArgoCD generate the secret, we supply one:
    kubectl apply -f bootstrap/argocd-secret.yaml
    # Needed to be able to sync from repo.
    kubectl apply -f bootstrap/argocd-repo-secret.yaml
    # Wait for ArgoCD to deploy.
    kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
    # Technically not needed as it'll get loaded on sync, this just speeds it up a little.
    kubectl apply -f bootstrap/argocd.yaml --force-conflicts --server-side
    # Sync everything else from the repo.
    kubectl apply -f root.yaml

[private]
wait_for_api:
    until kubectl get nodes 2>/dev/null | grep -q "NotReady\|Ready"; do sleep 5; done

