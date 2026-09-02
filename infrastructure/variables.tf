variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "talos_version" {
  type = string
}

variable "talos_image_factory_id" {
  type = string
}

variable "nodes" {
  description = "List of nodes and their configurations."
  type = list(object({
    hostname = string
    ip       = string
    cores    = string
    memory   = string
  }))
}

variable "cluster_name" {
  type = string
}

variable "kuberneters_version" {
  type = string
}

variable "cluster_vip" {
  type = string
}
