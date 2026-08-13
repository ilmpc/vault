resource "cloudflare_dns_record" "vaultwarden" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  type    = "A"
  content = yandex_compute_instance.vaultwarden.network_interface[0].nat_ip_address
  proxied = false
  ttl     = 1
}
