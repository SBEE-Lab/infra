resource "vultr_firewall_group" "eta" {
  description = "Firewall rules for eta"
}

resource "vultr_firewall_rule" "ssh" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 10022
  notes             = "SSH access on port 10022"
}

resource "vultr_firewall_rule" "http" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 80
  notes             = "HTTP access on port 80"
}

resource "vultr_firewall_rule" "https" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 443
  notes             = "HTTPS access on port 80"
}

resource "vultr_firewall_rule" "smtp" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 25
  notes             = "Stalwart SMTP"
}

resource "vultr_firewall_rule" "smtps" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 465
  notes             = "Stalwart implicit TLS submission"
}

resource "vultr_firewall_rule" "submission" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 587
  notes             = "Stalwart STARTTLS submission"
}

resource "vultr_firewall_rule" "imaps" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 993
  notes             = "Stalwart IMAPS"
}

resource "vultr_firewall_rule" "managesieve" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 4190
  notes             = "Stalwart ManageSieve"
}

resource "vultr_firewall_rule" "wireguard_mgnt" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 51820
  notes             = "WireGuard management interface"
}

resource "vultr_firewall_rule" "wireguard_serv" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 51821
  notes             = "WireGuard service interface"
}

resource "vultr_firewall_rule" "upterm" {
  firewall_group_id = vultr_firewall_group.eta.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = 2323
  notes             = "Upterm relay"
}


output "firewall_info" {
  description = "Firewall configuration details"
  value = {
    firewall_group_id   = vultr_firewall_group.eta.id
    description         = vultr_firewall_group.eta.description
    applied_to_instance = vultr_instance.eta.id
  }
}
