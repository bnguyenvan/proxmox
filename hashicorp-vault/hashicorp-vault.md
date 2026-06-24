## Vault Operation
- Engine:
  ```zsh
  vault secrets enable -path=secret kv
  vault secrets list
  ```
- KV secret:
```zsh
$ vault kv put secret/myapp/windows_vm_creds \
  admin_username="azureadmin" \
  admin_password="Secret@Password"
$ vault kv get secret/myapp/windows_vm_creds
```

## Vault Management
- Export bellow env variable for current terminal:
  ```zsh
  export VAULT_ADDR='https://vault.local.com' && export VAULT_CACERT=/Users/bongnguyen/Documents/github.com/Home/ssl_certificate/Secret/rootCA/rootCAcert.pem
  ```
- Login vault:
  ```zsh
  vault login
  ```

- Policy:
  ```zsh
  vault policy list
  vault policy write cloud-access cloud-access-policy.hcl
  vault policy delete cloud-access
  ```
- Token:
  ```zsh
  $ vault token create -policy="cloud-access"
  $ vault token revoke TOKEN_ID
  ```

## Config for Terraform authentication with vault

- Export Vault token using for terraform to authenticate wit vault root token:
  ```bash
  export TF_VAR_vault_token=TOKEN_HERE
  ```