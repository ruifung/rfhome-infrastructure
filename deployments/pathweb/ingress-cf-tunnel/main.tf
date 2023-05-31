variable "cf_account_id" {
  type = string
}

variable "cf_api_token" {
  type = string
}

provider "cloudflare" {
  api_token = var.cf_api_token
}

resource "random_id" "ingress_tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_tunnel" "ingress_tunnel" {
  account_id = var.cf_account_id
  name       = "rfhome-pathweb-ingress-tunnel"
  secret     = random_id.ingress_tunnel_secret.b64_std
}

resource "random_id" "cf_ingress_tunnel_token_tail" {
  byte_length = 8
  keepers = {
    data_sha = sha256(random_id.ingress_tunnel_secret.b64_std)
  }
}

resource "kubernetes_config_map_v1" "tunnel_info" {
  metadata {
    name      = "ingress-cf-tunnel-info"
    namespace = "traefik"
  }

  data = {
    "tunnel-cname" = cloudflare_tunnel.ingress_tunnel.cname
  }
}

resource "kubernetes_secret_v1" "tunnel_token" {
  metadata {
    name      = "ingress-cf-tunnel-token"
    namespace = "traefik"
  }

  data = {
    "token" = cloudflare_tunnel.ingress_tunnel.tunnel_token
  }
}

resource "cloudflare_record" "ingress_cname_record" {
  name    = "ingress-pathweb-clusters-home"
  proxied = true
  type    = "CNAME"
  value   = cloudflare_tunnel.ingress_tunnel.cname
  zone_id = "5bc68a047b2375ae7dbd5ccc3cc96912"
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
  }
}

moved {
  from = cloudflare_argo_tunnel.ingress_tunnel
  to = cloudflare_tunnel.ingress_tunnel
}
