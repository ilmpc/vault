resource "yandex_vpc_security_group" "vaultwarden" {
  name       = "vaultwarden"
  network_id = yandex_vpc_network.vaultwarden.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = var.ssh_allowed_cidrs
  }
  ingress {
    protocol       = "TCP"
    description    = "HTTP ACME"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "UDP"
    description    = "HTTP/3"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    description    = "Outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
