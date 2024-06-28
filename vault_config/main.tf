provider "vault" {}

resource "vault_kv_secret_v2" "demo-app-a" {
  mount = "secret"
  name  = "demo-app-a"
  data_json = jsonencode(
    {
      foo = "bar"
    }
  )
}

resource "vault_kv_secret_v2" "demo-app-b" {
  mount = "secret"
  name  = "demo-app-b"
  data_json = jsonencode(
    {
      bar = "foo"
    }
  )
}

resource "vault_auth_backend" "approle" {
  type = "approle"

}

resource "vault_policy" "demo" {
  name   = "demo"
  policy = <<EOF
path "secret/*" {
  capabilities = ["read"]
}
EOF
}

resource "vault_approle_auth_backend_role" "demo" {
  backend        = vault_auth_backend.approle.path
  role_name      = "demo"
  token_policies = [resource.vault_policy.demo.name]
}

resource "vault_approle_auth_backend_role_secret_id" "demo" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.demo.role_name
}

output "role_id" {
  value = resource.vault_approle_auth_backend_role.demo.role_id
}

output "secret_id" {
  value     = resource.vault_approle_auth_backend_role_secret_id.demo.secret_id
  sensitive = true
}