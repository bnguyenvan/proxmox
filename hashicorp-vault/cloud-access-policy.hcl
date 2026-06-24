# Allow reading AWS secrets and roles
path "aws/*" {
  capabilities = ["read", "list"]
}

# Allow reading Azure secrets and roles
path "azure/*" {
  capabilities = ["read", "list"]
}
path "auth/token/create" {
  capabilities = ["update"]
}