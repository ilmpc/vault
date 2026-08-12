provider "yandex" {
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

provider "cloudflare" { api_token = var.cloudflare_api_token }
