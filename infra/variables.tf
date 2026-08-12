variable "yc_cloud_id" { type = string }
variable "yc_folder_id" { type = string }
variable "yc_zone" {
  type    = string
  default = "ru-central1-a"
}
variable "domain_name" { type = string }
variable "cloudflare_zone_id" { type = string }
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
variable "vm_ssh_public_key" { type = string }
variable "ssh_allowed_cidrs" { type = list(string) }
variable "ubuntu_image_id" { type = string }
variable "backup_bucket_name" { type = string }
variable "backup_retention_days" {
  type    = number
  default = 30
}
variable "local_backup_keep" {
  type    = number
  default = 3
}
variable "vaultwarden_image" {
  type    = string
  default = "vaultwarden/server:1.34.3"
}
variable "caddy_image" {
  type    = string
  default = "caddy:2.10.2-alpine"
}
variable "vm_cores" {
  type    = number
  default = 2
}
variable "vm_memory" {
  type    = number
  default = 2
}
variable "data_disk_size_gb" {
  type    = number
  default = 20
}
