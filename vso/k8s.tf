variable "ns" {
  type = list(string)
  default = ["app-a", "app-b"]
}

data "terraform_remote_state" "vault_config" {
  backend = "local"
  config = {
    path = "../vault_config/terraform.tfstate"
  }
}

resource "kubernetes_secret" "secret_id" {
  for_each = { for idx, ns in var.ns : idx => ns }
  metadata {
    name      = "vso-approle-secretid"
    namespace = each.value
  }

  data = {
    id = data.terraform_remote_state.vault_config.outputs.secret_id
  }
  depends_on = [ kubernetes_namespace.ns ]
}

resource "kubernetes_namespace" "ns" {
  for_each = { for idx, ns in var.ns : idx => ns }
  metadata {
    name = each.value
  }
}

locals {
  namespace_names = [for ns in kubernetes_namespace.ns : ns.metadata[0].name]
}

resource "kubernetes_manifest" "vso-connection" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultConnection"
    "metadata" = {
      "name"      = "vso-connection"
      "namespace" = "vault-secrets-operator"
    }
    spec = {
      "address" = "http://vault.vault.svc:8200"
    }
  }

}

resource "kubernetes_manifest" "vso-auth" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultAuth"
    "metadata" = {
      "name"      = "vso-auth"
      "namespace" = "vault-secrets-operator"
    }
    spec = {
      "vaultConnectionRef" = "vso-connection"
      "method"             = "appRole"
      "mount"              = "approle"
      "allowedNamespaces"  = local.namespace_names
      "appRole" = {
        "roleId"    = data.terraform_remote_state.vault_config.outputs.role_id
        "secretRef" = "vso-approle-secretid"
      }
    }
  }

  depends_on = [ kubernetes_namespace.ns, kubernetes_manifest.vso-connection]
}

resource "kubernetes_manifest" "secrets" {
  for_each = { for idx, ns in var.ns : idx => ns }
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultStaticSecret"
    "metadata" = {
      "name"      = "vso-sync-${each.value}"
      "namespace" = each.value
    }
    spec = {
      "vaultAuthRef" = "vault-secrets-operator/vso-auth"
      "mount"        = "secret"
      "path"         = "demo-${each.value}"
      "refreshAfter" = "30s"
      "rolloutRestartTargets" = [
        {
          "kind" = "Deployment"
          "name" = "nginx"
        }
      ]
      "type" = "kv-v2"
      "destination" = {
        "create" = "true"
        "name"   = "vault-${each.value}"
      }
    }
  }

  depends_on = [ kubernetes_namespace.ns]
}

resource "kubernetes_deployment" "nginx" {
  for_each = { for idx, ns in var.ns : idx => ns }
  metadata {
    name      = "nginx"
    namespace = each.value
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app       = "nginx"
          namespace = each.value
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx"
          volume_mount {
            name       = "secret-volume"
            mount_path = "/etc/secrets"
            read_only  = true
          }
        }
        volume {
          name = "secret-volume"
          secret {
            secret_name = "vault-${each.value}"
          }
        }
      }
    }
  }

  depends_on = [ kubernetes_namespace.ns ]
}
