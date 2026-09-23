terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
  }
}

provider "proxmox" {
  insecure = true
  endpoint = "https://172.20.0.10:8006"
  username = var.username
  password = var.password
}

