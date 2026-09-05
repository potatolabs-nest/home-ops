resource "talos_machine_secrets" "machine_secrets" {
  talos_version = "v${var.talos_version}"
}

locals {
  node_ips                = [for node in var.nodes : node.ip]
  primary_control_node_ip = local.node_ips[0]
  install_image           = "factory.talos.dev/installer/${var.talos_image_factory_id}:v${var.talos_version}"
  cluster_endpoint        = "https://${local.primary_control_node_ip}:6443"
}

data "talos_client_configuration" "client_config" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = local.node_ips
  nodes                = local.node_ips
}

data "talos_machine_configuration" "control_machine_config" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.machine_secrets.machine_secrets
  kubernetes_version = "v${var.kuberneters_version}"
  talos_version      = "v${var.talos_version}"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda" # virtio0 disk
          image = local.install_image
        },
        network = {
          interfaces = [{
            interface = "eth0"
            vip = {
              ip = var.cluster_vip
            }
          }],
          nameservers = ["172.20.0.8", "45.90.28.254"]
        }
      }
    }),
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }),
    # Disables the Flannel, the default CNI for Talos
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
    }),
    # Disables kube-proxy, the default proxy service
    yamlencode({
      cluster = {
        proxy = {
          disabled = true
        }
      }
    }),
    # Trust OIDC
    yamlencode({
      cluster = {
        apiServer = {
          extraArgs = {
            "oidc-issuer-url"      = "https://fish.potatolabs.uk"
            "oidc-client-id"       = "headlamp"
            "oidc-username-claim"  = "preferred_username"
            "oidc-username-prefix" = "pocketid:"
            "oidc-groups-claim"    = "groups"
            "oidc-groups-prefix"   = "pocketid:"
          }
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "control_machine_config_apply" {
  for_each                    = { for node in var.nodes : node.hostname => node }
  depends_on                  = [proxmox_virtual_environment_vm.talos]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_machine_config.machine_configuration
  node                        = each.value.ip
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.control_machine_config_apply]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.primary_control_node_ip
  endpoint             = local.primary_control_node_ip
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.primary_control_node_ip
}

output "talosconfig" {
  value     = data.talos_client_configuration.client_config.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = resource.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}
