
```bash
sudo chown root:root /opt/vault/tls/vault-cert.pem /opt/vault/tls/rootCAcert.pem
sudo chown root:vault /opt/vault/tls/vault-key.pem
sudo chmod 0644 /opt/vault/tls/vault-cert.pem /opt/vault/tls/rootCAcert.pem
sudo chmod 0640 /opt/vault/tls/vault-key.pem
```

`vault.hcl`:
```bash
cluster_addr  = "https://192.168.31.21:8201"
api_addr      = "https://192.168.31.21:8200"
disable_mlock = true

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_cert_file      = "/opt/vault/tls/vault-cert.pem"
  tls_key_file       = "/opt/vault/tls/vault-key.pem"
#  tls_client_ca_file = "/opt/vault/tls/cacert.pem"
}
```


```bash
cluster_addr  = "https://192.168.31.21:8201"
api_addr      = "https://192.168.31.21:8200"
disable_mlock = true

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_cert_file      = "/opt/vault/tls/vault-cert.pem"
  tls_key_file       = "/opt/vault/tls/vault-key.pem"
  tls_client_ca_file = "/opt/vault/tls/cacert.pem"
}
```

# Check the status of Vault
In a new terminal session, export the VAULT_ADDR environment variable to address the server.
```bash
export VAULT_ADDR=https://127.0.0.1:8200
```

Vault uses strict verification of all TLS certificates by default. Since you're using a self-signed TLS certificate without a certificate authority, you should disable this strict checking by exporting the VAULT_SKIP_VERIFY environment variable and setting its value to true.
```bash
export VAULT_SKIP_VERIFY=true
```

To ensure Vault is running, you can use the vault status command. To ensure TLS connection can be validate, first set the VAULT_CACERT environment variable to the path of the CA root certificate.

```bash
export VAULT_CACERT=/opt/vault/tls/cacert.pem
```

# Adding rootCA to MacOS X
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /Users/bongnguyen/Documents/Secret/rootCA/rootCAcert.pem
```


Ref: [Set up Vault](https://developer.hashicorp.com/vault/tutorials/get-started/setup)