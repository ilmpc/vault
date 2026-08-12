resource "yandex_vpc_network" "vaultwarden" { name = "vaultwarden" }

resource "yandex_vpc_subnet" "vaultwarden" {
  name           = "vaultwarden-${var.yc_zone}"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.vaultwarden.id
  v4_cidr_blocks = ["10.20.0.0/24"]
}

resource "yandex_vpc_address" "vaultwarden" {
  name = "vaultwarden-ip"
  external_ipv4_address { zone_id = var.yc_zone }
}
