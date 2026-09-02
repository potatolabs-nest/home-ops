[doc("Decrypt required files committed to git")]
decrypt_required:
    just secrets decrypt_cluster_config
    just secrets decrypt_terraform_secrets
    just secrets decrypt_terraform_state

[doc("Encrypt talosconfig and kubeconfig")]
[working-directory('../infrastructure')]
encrypt_cluster_config:
    sops --encrypt kubeconfig.yaml > kubeconfig.encrypted.yaml
    sops --encrypt talosconfig.yaml > talosconfig.encrypted.yaml

[doc("Decrypt talosconfig and kubeconfig")]
[working-directory('../infrastructure')]
decrypt_cluster_config:
    sops --decrypt talosconfig.encrypted.yaml > talosconfig.yaml
    sops --decrypt kubeconfig.encrypted.yaml > kubeconfig.yaml
    chmod 600 talosconfig.yaml kubeconfig.yaml

[doc("Encrypt secrets.auto.tfvars")]
[working-directory('../infrastructure')]
encrypt_terraform_secrets:
    sops --encrypt secrets.auto.tfvars > secrets.auto.encrypted.tfvars

[doc("Decrypt secrets.auto.tfvars")]
[working-directory('../infrastructure')]
decrypt_terraform_secrets:
    sops --decrypt secrets.auto.encrypted.tfvars > secrets.auto.tfvars
    chmod 600 secrets.auto.tfvars

[doc("Encrypt terraform.tfstate")]
[working-directory('../infrastructure')]
encrypt_terraform_state:
    sops --encrypt --input-type json --output-type json terraform.tfstate > terraform.encrypted.tfstate

[doc("Decrypt terraform.tfstate")]
[working-directory('../infrastructure')]
decrypt_terraform_state:
    # If the encrypted state doesn't exist yet (fresh repo), skip silently.
    test -f terraform.encrypted.tfstate || exit 0
    sops --decrypt --input-type json --output-type json terraform.encrypted.tfstate > terraform.tfstate
    chmod 600 terraform.tfstate

[doc("Restore sealed-secrets-key.yaml")]
[working-directory('../infrastructure')]
restore_sealed_secrets_private_key:
    # If the encrypted private key doesn't exist, skip the whole recipe.
    test -f sealed-secrets-key.encrypted.yaml || exit 0
    just secrets::decrypt_sealed_secrets_private_key
    # Don't exit if namespace already exists.
    kubectl create namespace sealed-secrets || true
    # Restore the private key.
    kubectl apply -f sealed-secrets-key.yaml
    rm sealed-secrets-key.yaml
    # We may need to restart the controller, but it may not exist, which is fine.
    kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets || true

[doc("Fetch sealed-secrets-cert.pem, necessary to encrypt secrets offline")]
[working-directory('../infrastructure')]
fetch_sealed_secrets_cert:
    kubeseal --fetch-cert \
             --controller-name=sealed-secrets-controller \
             --controller-namespace=sealed-secrets \
        > sealed-secrets-cert.pem

[doc("Fetch sealed-secrets-key.yaml")]
[working-directory('../infrastructure')]
fetch_sealed_secrets_private_key:
    kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o yaml > sealed-secrets-key.yaml
    just secrets::encrypt_sealed_secrets_private_key
    rm sealed-secrets-key.yaml

[doc("Encrypt sealed-secrets-key.yaml")]
[working-directory('../infrastructure')]
encrypt_sealed_secrets_private_key:
    sops --encrypt sealed-secrets-key.yaml > sealed-secrets-key.encrypted.yaml

[doc("Decrypt sealed-secrets-key.yaml")]
[working-directory('../infrastructure')]
decrypt_sealed_secrets_private_key:
    sops --decrypt sealed-secrets-key.encrypted.yaml > sealed-secrets-key.yaml

