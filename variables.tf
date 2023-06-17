variable "proxmox_url" {
  description = "URL of the Proxmox server"
  type        = string
}

variable "proxmox_user" {
  description = "User for the Proxmox server"
  type        = string
}

variable "proxmox_password" {
  description = "Password for the Proxmox user"
  type        = string
  sensitive   = true
}
