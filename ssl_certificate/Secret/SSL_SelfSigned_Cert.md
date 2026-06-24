# CREATE SELF-SIGNED SSL CERTIFICATE

## Step 1

First you set up your CA, and then you sign an end entity certificate (a.k.a server or user). Both of the two commands elide the two steps into one. And both assume you have a an OpenSSL configuration file already setup for both CAs and Server (end entity) certificates.

First, create a basic [configuration file](https://raw.githubusercontent.com/openssl/openssl/master/apps/openssl.cnf):
```zsh
touch ./rootCA/openssl-ca-1.cnf
```

Then, add the following to it:

`openssl-ca-1.cnf`
```zsh
HOME            = .
RANDFILE        = $ENV::HOME/.rnd

####################################################################
[ ca ]
default_ca    = CA_default      # The default ca section

[ CA_default ]

default_days     = 365          # How long to certify for
default_crl_days = 30           # How long before next CRL
default_md       = sha256       # Use public key default MD
preserve         = no           # Keep passed DN ordering

x509_extensions = ca_extensions # The extensions to add to the cert

email_in_dn     = no            # Don't concat the email in the DN
copy_extensions = copy          # Required to copy SANs from CSR to cert

####################################################################
[ req ]
default_bits       = 4096
default_keyfile    = cakey.pem
distinguished_name = ca_distinguished_name
x509_extensions    = ca_extensions
string_mask        = utf8only

####################################################################
[ ca_distinguished_name ]
countryName         = Country Name (2 letter code)
countryName_default = VN

stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Viet Nam

localityName                = Locality Name (eg, city)
localityName_default        = HO CHI MINH

organizationName            = Organization Name (eg, company)
organizationName_default    = Duc Loi

organizationalUnitName         = Organizational Unit (eg, division)
organizationalUnitName_default = IT

commonName         = Common Name (e.g. server FQDN or YOUR name)
commonName_default = Self CA

emailAddress         = Email Address
emailAddress_default = microwave88@gmail.com

####################################################################
[ ca_extensions ]

subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always, issuer
basicConstraints       = critical, CA:true
keyUsage               = keyCertSign, cRLSign
```

The fields above are taken from a more complex `openssl.cnf` (you can find it in `/usr/lib/openssl.cnf`), but I think they are the essentials for creating the CA certificate and private key.

Tweak the fields above to suit your taste. The defaults save you the time from entering the same information while experimenting with configuration file and command options.

I omitted the CRL-relevant stuff, but your CA operations should have them. See `openssl.cnf` and the related `crl_ext` section.

Then, execute the following. The `-nodes` omits the password or passphrase so you can examine the certificate. It's a really **bad** idea to omit the password or passphrase.

```bash
openssl req -x509 -config ./rootCA/openssl-ca-1.cnf -days 3650 -newkey rsa:4096 -sha256 -out ./rootCA/rootCAcert.pem -outform PEM
```

After the command executes, `cacert.pem` will be your certificate for CA operations, and `cakey.pem` will be the private key. Recall the private key does not have a password or passphrase.

You can dump the certificate with the following.

```zsh
$ openssl x509 -in cacert.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            a2:6a:6f:e9:e0:ff:8b:8c
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=VN, ST=Viet Nam, L=HO CHI MINH, O=Duc Loi, OU=IT, CN=Self CA/emailAddress=microwave88@gmail.com
        Validity
            Not Before: May 26 02:29:27 2025 GMT
            Not After : May 24 02:29:27 2035 GMT
        Subject: C=VN, ST=Viet Nam, L=HO CHI MINH, O=Duc Loi, OU=IT, CN=Self CA/emailAddress=microwave88@gmail.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (4096 bit)
                Modulus:
                    00:f5:a1:aa:81:c9:78:79:55:9f:bc:73:08:db:a9:
                    ...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier:
                C6:0D:F6:90:AB:47:A7:47:DF:4F:10:AF:A1:DF:8A:DF:CF:D7:9D:BD
            X509v3 Authority Key Identifier:
                keyid:C6:0D:F6:90:AB:47:A7:47:DF:4F:10:AF:A1:DF:8A:DF:CF:D7:9D:BD

            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Key Usage:
                Certificate Sign, CRL Sign
    Signature Algorithm: sha256WithRSAEncryption
         ac:60:b4:6f:53:67:f6:f3:3b:63:76:c0:7a:77:68:64:3c:d4:
         ...
```

And test its purpose with the following (don't worry about the Any Purpose: Yes; see ["critical,CA:FALSE" but "Any Purpose CA : Yes"](https://openssl-dev.openssl.narkive.com/jQuMsYl5/critical-ca-false-but-any-purpose-ca-yes)).

```zsh
$ openssl x509 -purpose -in cacert.pem -inform PEM
Certificate purposes:
SSL client : No
SSL client CA : Yes
SSL server : No
SSL server CA : Yes
Netscape SSL server : No
Netscape SSL server CA : Yes
S/MIME signing : No
S/MIME signing CA : Yes
S/MIME encryption : No
S/MIME encryption CA : Yes
CRL signing : Yes
CRL signing CA : Yes
Any Purpose : Yes
Any Purpose CA : Yes
OCSP helper : Yes
OCSP helper CA : Yes
Time Stamp signing : No
Time Stamp signing CA : Yes
-----BEGIN CERTIFICATE-----
MIIF/zCCA+egAwIBAgIJAKJqb+ng/4uMMA0GCSqGSIb3DQEBCwUAMIGNMQswCQYD
...
dDwfAZO15BsGaNjkE3DxZT0UmR6wIj7UysW0nq7+9nbJV+eGJ8+eVfmKx7mjRGVT
D1zi
```

## Step 2
For part two, I'm going to create another configuration file that's easily digestible. First, touch the openssl-server.cnf (you can make one of these for user certificates also).
```zsh
touch openssl-server.cnf
```

Then open it, and add the following.

`openssl-server.cnf`

```cnf
HOME            = .
RANDFILE        = $ENV::HOME/.rnd

####################################################################
[ req ]
default_bits       = 2048
default_keyfile    = vault-key.pem
distinguished_name = server_distinguished_name
req_extensions     = server_req_extensions
string_mask        = utf8only

####################################################################
[ server_distinguished_name ]
countryName         = Country Name (2 letter code)
countryName_default = VN

stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Viet Nam

localityName         = Locality Name (eg, city)
localityName_default = HO CHI MINH

organizationName            = Organization Name (eg, company)
organizationName_default    = Duc Loi

commonName           = Common Name (e.g. server FQDN or YOUR name)
commonName_default   = Vault Server

emailAddress         = Email Address
emailAddress_default = microwave88@gmail.com

####################################################################
[ server_req_extensions ]

subjectKeyIdentifier = hash
basicConstraints     = CA:FALSE
keyUsage             = digitalSignature, keyEncipherment
subjectAltName       = @alternate_names
nsComment            = "OpenSSL Generated Certificate"

####################################################################
[ alternate_names ]

DNS.1  = vault.ducloi
DNS.2  = www.vault.ducloi
```

If you are developing and need to use your workstation as a server, then you may need to do the following for Chrome. Otherwise Chrome may complain a Common Name is invalid (ERR_CERT_COMMON_NAME_INVALID). I'm not sure what the relationship is between an IP address in the SAN and a CN in this instance. Adding bellow to `[ alternate_names ]` part

`openssl-server.cnf`

```cnf
# IPv4 localhost
IP.1     = 127.0.0.1
# IPv6 localhost
IP.2     = ::1
# IPv4 external
IP.3   = 192.168.31.21
```

Then, create the server certificate request. Be sure to omit `-x509*`. Adding `-x509` will create a certificate, and not a request.
```bash
openssl req -config openssl-server.cnf -newkey rsa:2048 -sha256 -nodes -out vault-cert.csr -outform PEM
```
After this command executes, you will have a request in `vault-cert.csr` and a private key in `vault-key.pem`

And you can inspect it again.
```zsh
$ openssl req -text -noout -verify -in vault-cert.csr
verify OK
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject: C=VN, ST=Viet Nam, L=HO CHI MINH, O=Duc Loi, CN=Vault Server/emailAddress=microwave88@gmail.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:f0:7e:a2:6e:d9:5a:d7:46:ee:d4:a4:61:cb:63:
                    ...
                    15:fd
                Exponent: 65537 (0x10001)
        Attributes:
        Requested Extensions:
            X509v3 Subject Key Identifier:
                A7:03:A8:A4:2D:4D:94:4B:35:17:4C:DA:C9:B7:53:C2:6D:18:E9:E3
            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Key Usage:
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name:
                DNS:vault.ducloi, DNS:www.vault.ducloi, IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1, IP Address:192.168.31.21
            Netscape Comment:
                OpenSSL Generated Certificate
    Signature Algorithm: sha256WithRSAEncryption
         de:e9:23:d5:df:08:94:1c:14:b3:df:1b:4a:17:84:3b:84:dc:
         ...
         d8:ff:dd:f5
```

Next, you have to sign it with your CA.

You are almost ready to sign the server's certificate by your CA. The CA's `openssl-ca-1.cnf` needs two more sections before issuing the command.

First, create new config file for convinient with same content as `openssl-ca-1.cnf`

```zsh
cp openssl-ca-1.cnf openssl-ca-2.cnf
```

Then open `openssl-ca-2.cnf` and add the following two sections.

`openssl-ca-2.cnf`
```bash
####################################################################
[ signing_policy ]
countryName            = optional
stateOrProvinceName    = optional
localityName           = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

####################################################################
[ signing_req ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, keyEncipherment
```

Second, add the following to the `[ CA_default ]` section of `openssl-ca-2.cnf`. I left them out earlier, because they can complicate things (they were unused at the time). Now you'll see how they are used, so hopefully they will make sense.

`openssl-ca-2.cnf`
```bash
base_dir      = .
certificate   = $base_dir/cacert.pem   # The CA certifcate
private_key   = $base_dir/cakey.pem    # The CA private key
new_certs_dir = $base_dir              # Location for new certs after signing
database      = $base_dir/index.txt    # Database index file
serial        = $base_dir/serial.txt   # The current serial number

unique_subject = no  # Set to 'no' to allow creation of
                   #  several certificates with same subject.
```

Third, touch index.txt and serial.txt:

```bash
touch index.txt
echo '01' > serial.txt
```

Then, perform the following:

```bash
openssl ca -config openssl-ca-2.cnf -policy signing_policy -extensions signing_req -out vault-cert.pem -infiles vault-cert.csr
```

You should see similar to the following:

```zsh
Using configuration from openssl-ca-2.cnf
Enter pass phrase for ./cakey.pem:
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
countryName           :PRINTABLE:'VN'
stateOrProvinceName   :ASN.1 12:'Viet Nam'
localityName          :ASN.1 12:'HO CHI MINH'
organizationName      :ASN.1 12:'Duc Loi'
commonName            :ASN.1 12:'Vault Server'
Certificate is to be certified until May 26 04:17:42 2026 GMT (365 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
```

After the command executes, you will have a freshly minted server certificate in `vault-cert.pem`. The private key was created earlier and is available in `vault-key.pem`.

Finally, you can inspect your freshly minted certificate with the following:

```zsh
$ openssl x509 -in vault-cert.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 1 (0x1)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=VN, ST=Viet Nam, L=HO CHI MINH, O=Duc Loi, OU=IT, CN=Self CA/emailAddress=microwave88@gmail.com
        Validity
            Not Before: May 26 04:17:42 2025 GMT
            Not After : May 26 04:17:42 2026 GMT
        Subject: C=VN, ST=Viet Nam, L=HO CHI MINH, O=Duc Loi, CN=Vault Server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:f0:7e:a2:6e:d9:5a:d7:46:ee:d4:a4:61:cb:63:
                    ...
                    88:66:bd:56:85:32:2c:b2:ff:28:83:a9:9f:c4:65:
                    15:fd
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier:
                A7:03:A8:A4:2D:4D:94:4B:35:17:4C:DA:C9:B7:53:C2:6D:18:E9:E3
            X509v3 Authority Key Identifier:
                keyid:C6:0D:F6:90:AB:47:A7:47:DF:4F:10:AF:A1:DF:8A:DF:CF:D7:9D:BD

            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Key Usage:
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name:
                DNS:vault.ducloi, DNS:www.vault.ducloi, IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1, IP Address:192.168.31.21
            Netscape Comment:
                OpenSSL Generated Certificate
    Signature Algorithm: sha256WithRSAEncryption
         ae:69:16:34:e0:15:99:29:3c:db:2d:6b:4a:73:70:94:4e:2c:
         ...
         b9:7e:5e:30:10:a4:48:0d:a5:47:e2:03:2e:03:50:5e:8f:2c:
         12:ff:c1:9b:f4:ac:e7:df
```

---
Earlier, you added the following to CA_default: copy_extensions = copy. This copies extension provided by the person making the request.

If you omit copy_extensions = copy, then your server certificate will lack the Subject Alternate Names (SANs) like www.example.com and mail.example.com.

If you use copy_extensions = copy, but don't look over the request, then the requester might be able to trick you into signing something like a subordinate root (rather than a server or user certificate). Which means he/she will be able to mint certificates that chain back to your trusted root. Be sure to verify the request with openssl req -verify before signing

---

If you omit unique_subject or set it to yes, then you will only be allowed to create one certificate under the subject's distinguished name.

```cnf
unique_subject = yes            # Set to 'no' to allow creation of
                                # several ctificates with same subject.
```

Trying to create a second certificate while experimenting will result in the following when signing your server's certificate with the CA's private key:

```zsh
Sign the certificate? [y/n]:Y
failed to update database
TXT_DB error number 2
```

So unique_subject = no is perfect for testing.

---
If you want to ensure the Organizational Name is consistent between self-signed CAs, Subordinate CA and End-Entity certificates, then add the following to your CA configuration files:

```cnf
[ policy_match ]
organizationName = match
```

If you want to allow the Organizational Name to change, then use:

```cnf
[ policy_match ]
organizationName = supplied
```

There are other rules concerning the handling of DNS names in X.509/PKIX certificates. Refer to these documents for the rules:

- RFC 5280, [Internet X.509 Public Key Infrastructure Certificate and Certificate Revocation List (CRL) Profile](https://www.rfc-editor.org/rfc/rfc5280)
- RFC 6125, [Representation and Verification of Domain-Based Application Service Identity within Internet Public Key Infrastructure Using X.509 (PKIX) Certificates in the Context of Transport Layer Security (TLS)](https://www.rfc-editor.org/rfc/rfc6125)
- RFC 6797, Appendix A, [HTTP Strict Transport Security (HSTS)](https://www.rfc-editor.org/rfc/rfc6797)
- RFC 7469, [Public Key Pinning Extension for HTTP](https://www.rfc-editor.org/rfc/rfc7469)
- CA/Browser Forum [Baseline Requirements](https://cabforum.org/baseline-requirements-documents/)
- CA/Browser Forum [Extended Validation Guidelines](https://cabforum.org/extended-validation-2/)

RFC 6797 and RFC 7469 are listed, because they are more restrictive than the other RFCs and CA/B documents. RFC's 6797 and 7469 do not allow an IP address, either.

## Decrypt key file if needed
```zsh
openssl rsa -in ./rootCA/rootCAkey.pem -out ./rootCA/rootCAkey_decrypt.pem
```

# SUMMARY

Create certificate for `*.local.com` domain

```zsh
cd local.com
vim local.com-config.cnf
```
Edit all area with comment `#CHANGE HERE`

Generate certificate, note that Apple require certificate must have SAN (Subject Alternative Name) and Validity Must Be ≤ 825 Days. Otherwise, safari will not accept certificate
```zsh
cd /Users/bongnguyen/Documents/github.com/Home/ssl_certificate/Secret

PREFIX=local.com
HOME_DIR=/Users/bongnguyen/Documents/github.com/Home/ssl_certificate/Secret
WORKING_DIR=$HOME_DIR/$PREFIX
CERT_CONFIG=$WORKING_DIR/$PREFIX-config.cnf
CERT_CSR=$WORKING_DIR/$PREFIX-cert.csr
CERT_FILE=$WORKING_DIR/$PREFIX-cert.pem

openssl req -config $CERT_CONFIG -newkey rsa:2048 -sha256 -nodes -out $CERT_CSR -outform PEM

openssl ca -config $HOME_DIR/rootCA/openssl-ca-2.cnf \
    -policy signing_policy -extensions signing_req \
    -out $CERT_FILE -infiles $CERT_CSR
```

From GPT:
```zsh
openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
  -keyout server.key -out server.crt \
  -config openssl.cnf -extensions v3_ca
```

Clearnup
```zsh

```

Reference: [How do you sign a Certificate Signing Request with your Certification Authority?](https://stackoverflow.com/questions/21297139/how-do-you-sign-a-certificate-signing-request-with-your-certification-authority/21340898#21340898)