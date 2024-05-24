resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
  ]
  validity_period_hours = 12
  is_ca_certificate     = true

  subject {
    common_name  = "pandaproxy-benchmarking"
    organization = "pandaproxy-benchmarking"
  }
}

resource "tls_private_key" "broker" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "broker" {
  ip_addresses    = ["127.0.0.1"]
  private_key_pem = tls_private_key.broker.private_key_pem
}

resource "tls_locally_signed_cert" "broker" {
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  ca_private_key_pem    = tls_self_signed_cert.ca.private_key_pem
  cert_request_pem      = tls_cert_request.broker.cert_request_pem
  validity_period_hours = 12
}


resource "local_sensitive_file" "ca_crt" {
  filename = "ca.crt"
  content  = tls_self_signed_cert.ca.cert_pem
}

resource "local_sensitive_file" "broker_crt" {
  filename = "broker.crt"
  content  = tls_locally_signed_cert.broker.cert_pem
}

resource "local_sensitive_file" "broker_key" {
  filename = "broker.key"
  content  = tls_private_key.broker.private_key_pem
}
