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
variable "os_login_user_id" {
  type    = string
  default = ""
}
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
  default = "vaultwarden/server:1.37.1"
}
variable "caddy_image" {
  type    = string
  default = "caddy:2.11.4"
}
variable "docker_registry_mirror" {
  type    = string
  default = "https://dockerhub.timeweb.cloud"
}
variable "vm_cores" {
  type    = number
  default = 2
}
variable "vm_memory" {
  type    = number
  default = 1
}
variable "vm_core_fraction" {
  type    = number
  default = 20
}
