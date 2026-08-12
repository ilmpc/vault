terraform {
  required_version = ">= 1.8.0"
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.0" }
    yandex     = { source = "yandex-cloud/yandex", version = ">= 0.100" }
  }
}
