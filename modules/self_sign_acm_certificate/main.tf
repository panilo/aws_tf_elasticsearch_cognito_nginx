# CREATE THE PRIVATE KEY
resource "tls_private_key" "key" {
  algorithm = "RSA"
}

# CREATE THE CERTIFICATE
resource "tls_self_signed_cert" "ssc" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.key.private_key_pem

  subject {
    common_name         = var.domain_name
    organization        = var.organization
    organizational_unit = var.organizational_unit
    street_address      = var.street_address
    locality            = var.locality
    province            = var.province
    country             = var.country
    postal_code         = var.postal_code
    serial_number       = var.serial_number
  }

  validity_period_hours = 8640 # 1Y

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

# IMPORT IT
resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.key.private_key_pem
  certificate_body = tls_self_signed_cert.ssc.cert_pem

  tags = var.tags
}
