resource "proxmox_download_file" "talos_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = "pve01"
  url                     = "https://factory.talos.dev/image/${var.talos_image_factory_id}/v${var.talos_version}/nocloud-amd64.raw.xz"
  decompression_algorithm = "zst"
  file_name               = "talos-v${var.talos_version}-nocloud-amd64.img"
  overwrite               = false
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each        = { for node in var.nodes : node.hostname => node }
  name            = each.key
  tags            = ["terraform", "talos"]
  node_name       = "pve01"
  machine         = "q35"
  bios            = "ovmf"
  on_boot         = true
  stop_on_destroy = true

  agent {
    enabled = true
  }
  efi_disk {
    datastore_id      = "local-lvm"
    type              = "4m"
    file_format       = "raw"
    pre_enrolled_keys = "false"
  }
  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.talos_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 40
  }
  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "172.20.0.1"
      }
    }
  }
  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }
  memory {
    dedicated = each.value.memory
    floating  = each.value.memory
  }
  network_device {
    bridge = "vmbr0"
  }
  operating_system {
    type = "l26"
  }
}
