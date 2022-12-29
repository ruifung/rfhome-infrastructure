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

resource "cloudflare_argo_tunnel" "ingress_tunnel" {
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
    name = "ingress-cf-tunnel-info"
    namespace = "traefik"
  }

  data = {
    "tunnel-cname" = cloudflare_argo_tunnel.ingress_tunnel.cname
  }
}

resource "kubernetes_secret_v1" "tunnel_token" {
  metadata {
    name = "ingress-cf-tunnel-token"
    namespace = "traefik"
  }

  data = {
    "token" = cloudflare_argo_tunnel.ingress_tunnel.tunnel_token
  }
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.16.1"
    }
  }
}
