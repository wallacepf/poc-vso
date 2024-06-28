provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
  
}

resource "kubernetes_secret" "vault-license" {
  metadata {
    name      = "vault-enterprise-license"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }

  data = {
    "license" = file("license.hclic")
  }

}

resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"

  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "server.image.repository"
    value = "hashicorp/vault-enterprise"
  }

  set {
    name  = "server.image.tag"
    value = "1.17.1-ent"
  }

  set {
    name  = "ui.enabled"
    value = true
  }

  set {
    name  = "ui.serviceType"
    value = "LoadBalancer"
  }
  set {
    name  = "server.enterpriseLicense.secretName"
    value = kubernetes_secret.vault-license.metadata[0].name
  }
}

resource "helm_release" "vso" {
  name             = "vault-vso"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  namespace        = "vault-secrets-operator"
  create_namespace = true
}