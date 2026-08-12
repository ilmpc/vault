resource "cloudflare_dns_record" "vaultwarden" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  type    = "A"
  content = yandex_vpc_address.vaultwarden.external_ipv4_address[0].address
  proxied = false
  ttl     = 1
}
