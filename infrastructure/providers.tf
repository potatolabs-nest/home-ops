terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.113.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
  }
}

provider "proxmox" {
  insecure = true
  endpoint = "https://172.20.0.10:8006"
  username = var.username
  password = var.password
}

