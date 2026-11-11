# 4 gNSI Use Cases

gNSI services and RPCs secure access to the switch and cover security operations on it. This includes authorization policies for gRPC service access, certificate management and accounting.

In this section, we will look at some of these features.

>[!IMPORTANT]
> The gNSIc client we will be using during this workshop had a small patch applied to it, to allow it to work with newer versions of SR Linux.  
> We are in the process of upstreaming this patch.
> If you are following this workshop along at home, without access to the VM, please download a release from or build using the fork located here:
> https://github.com/mabra94/gnsic 

## 4.1 gNSI Authz

The **gNSI Auth** RPC configures an authorization policy for access to gRPC services.

In the previous section on gNOI, we used a user `gnoic1` to get the configuration file backup to the host VM. Because there are no authorization policies in place, this user can also transfer files to the switch.

If an unauthorized third party gets access to the host VM, they can use the same user to push corrupted files or images to the switch.

We will be using gNSI to configure an authorization policy on leaf1 that will prevent the user called `gnoic1` (used for config file backup) from writing files on the switch.

Let's start by verifying that the user `gnoic1` has access to list, get and put files on leaf1.

We will switch to secure gRPC communication for this section, using the TLS-secured gRPC server running on port 57400, because gNSI policies apply to secure requests only.  
Due to not having a valid signed certificate, we will need to add `--skip-verify` to our `gnoic` and `gnsic` commands.

### 4.1.1 List File

Let's first perform a simple gNOI File Stat on `/etc/opt/srlinux/config.json` to test the TLS-secured gRPC server on `leaf1`.

```bash
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file stat --path /etc/opt/srlinux/config.json
```

Expected output:

```bash
+-------------+------------------------------+---------------------------+------------+------------+--------+
| Target Name |             Path             |       LastModified        |    Perm    |   Umask    |  Size  |
+-------------+------------------------------+---------------------------+------------+------------+--------+
| leaf1:57400 | /etc/opt/srlinux/config.json | 2025-05-20T02:50:43-04:00 | -rw-rw-r-- | -----w--w- | 105988 |
+-------------+------------------------------+---------------------------+------------+------------+--------+
```

### 4.1.2 Get File

```bash
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file get --file /etc/opt/srlinux/config.json --dst .
```

Expected output:

```bash
INFO[0000] "leaf1:57400" received 64000 bytes           
INFO[0000] "leaf1:57400" received 62835 bytes           
INFO[0000] "leaf1:57400" file "/etc/opt/srlinux/config.json" saved
```

### 4.1.3 Put File

Create a file on your host VM:

```bash
echo "this is a corrupted image file" > corrupt.img
```

Now transfer this file to the switch.

```bash
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file put --file corrupt.img --dst /var/log/srlinux/corrupt.img
```

Expected output for Put file:

```bash
INFO[0000] "leaf1:57400" sending file="corrupt.img" hash 
INFO[0000] "leaf1:57400" file "corrupt.img" written successfully 
```

Verify on leaf1 that the transferred file exists.

```bash
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file stat --path /var/log/srlinux/corrupt.img
```

Expected output:

```bash
+-------------+------------------------------+----------------------+------------+------------+------+
| Target Name |             Path             |     LastModified     |    Perm    |   Umask    | Size |
+-------------+------------------------------+----------------------+------------+------------+------+
| leaf1:57400 | /var/log/srlinux/corrupt.img | 2026-11-11T11:51:45Z | -rwxrwxrwx | -----w--w- | 31   |
+-------------+------------------------------+----------------------+------------+------------+------+
```

### 4.1.4 Remove the Transferred File

Delete the transferred file using the gNOI File Remove RPC.

```bash
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file remove --path /var/log/srlinux/corrupt.img
```

Expected output:

```bash
INFO[0000] "leaf1:57400" file "/var/log/srlinux/corrupt.img" removed successfully 
```

### 4.1.5 Push the Authz Policy

At this point, we verified that user `gnoic1` has permission to transfer a file over to leaf1.

Let's block that by pushing an authorization policy with the gNSI Authz service!

This is the Authz policy payload that we will push. It gives the user `gnoic1` access to gNOI File Get and File Stat RPCs, and denies the gNOI File Put RPC.

<details>
<summary>Authz Payload</summary>

```json
{
  "name": "Ext-clients",
  "allow_rules": [
    {
      "name": "backup-access",
      "source": {
        "principals": [
          "gnoic1",
          "gnoi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnoi.file.File/Get",
          "/gnoi.file.File/Stat"
        ]
      }
    }
  ],
  "deny_rules": [
    {
      "name": "backup-access",
      "source": {
        "principals": [
          "gnoic1",
          "gnoi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnoi.file.File/Put"
        ]
      }
    }
  ]
}
```

</details>

We have pre-formatted this for you, so you can easily paste the entire `gnsic` command into your terminal.

```bash
gnsic -a leaf1 -u admin -p NokiaSrl1! --skip-verify authz rotate --policy "{\"name\":\"Ext-clients\",\"allow_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Get\",\"/gnoi.file.File/Stat\"]}}],\"deny_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Put\"]}}]}"
```

Expected output:

```bash
INFO[0000] targets: map[leaf1:57400:0xc0002c6040]       
INFO[0000] "leaf1:57400": got UploadResponse            
INFO[0001] "leaf1:57400": sending finalize request      
INFO[0001] "leaf1:57400": closing stream 
```

Verify that the Authz policy was applied on the system. We will use gNMI Get RPC for this purpose.

```bash
gnmic -a leaf1 -u admin -p NokiaSrl1! --skip-verify get --path /system/aaa/authorization/authz-policy --encoding json_ietf
```

Expected output:

```json
[
  {
    "source": "leaf1",
    "timestamp": 1794398428823103117,
    "time": "2026-11-11T12:00:28.823103117Z",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-aaa:aaa/authorization/srl_nokia-gnsi-authz:authz-policy",
        "values": {
          "srl_nokia-system:system/srl_nokia-aaa:aaa/authorization/srl_nokia-gnsi-authz:authz-policy": {
            "counters": {
              "rpc": [
                {
                  "access-accepts": "6",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-10T14:20:15.088Z",
                  "name": "/gnmi.gNMI/Capabilities"
                },
                {
                  "access-accepts": "32",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T12:00:28.821Z",
                  "name": "/gnmi.gNMI/Get"
                },
                {
                  "access-accepts": "17",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:13:09.553Z",
                  "name": "/gnmi.gNMI/Set"
                },
                {
                  "access-accepts": "39",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:37:39.320Z",
                  "name": "/gnmi.gNMI/Subscribe"
                },
                {
                  "access-accepts": "1",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:51:10.503Z",
                  "name": "/gnoi.file.File/Get"
                },
                {
                  "access-accepts": "1",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:51:45.496Z",
                  "name": "/gnoi.file.File/Put"
                },
                {
                  "access-accepts": "1",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:52:16.526Z",
                  "name": "/gnoi.file.File/Remove"
                },
                {
                  "access-accepts": "4",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:52:16.501Z",
                  "name": "/gnoi.file.File/Stat"
                },
                {
                  "access-accepts": "1",
                  "access-rejects": "0",
                  "last-access-accept": "2026-11-11T11:57:23.079Z",
                  "name": "/gnsi.authz.v1.Authz/Rotate"
                }
              ]
            },
            "created-on": "2362-06-18T21:06:29.009Z",
            "policy": "{\"name\":\"Ext-clients\",\"allow_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Get\",\"/gnoi.file.File/Stat\"]}}],\"deny_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Put\"]}}]}",
            "version": ""
          }
        }
      }
    ]
  }
]
```

> [!WARNING]
> Because the gNSIc client is in beta, it might not push the policy on the first attempt. If gNMI Get is still showing the default policy, repeat the gNSIc Authz command to push the policy again.

Now test the gNOI List, Get and Put file operations again using the `gnoic1` user!

Refer to the steps in [Section 4.1](#41-gnsi-authz).

The Put operation is denied by the Authz Policy, with the following output.

```bash
INFO[0000] "leaf1:57400" sending file="corrupt.img" hash 
ERRO[0000] "leaf1:57400" File Put failed: rpc error: code = PermissionDenied desc = User 'gnoic1' is not authorized to use rpc '/gnoi.file.File/Put' 
Error: there was 1 error(s)
```

### 4.1.6 Clear the Authz Policy

Log in to the `leaf1` CLI and run the following command:

```bash
tools system aaa authorization authz-policy remove
```

## 4.2 TLS Certificate Management

Another gNSI use-case is configuring and managing TLS profiles and certificates on the switch.  
The gNSI **Certz RPCs** handle this.

Assuming our starting point is an insecure connection, we will build a TLS profile with certificates and use it on a gRPC server to make our connection secure.

### 4.2.1 Create a TLS Profile

```bash
gnsic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure certz add-profile --id Corp-Sec-A
```

Expected output:

```bash
INFO[0000] leaf1:57401: added profile "Corp-Sec-A"
```

### 4.2.2 Verify TLS Profiles

```bash
gnsic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure certz get-profile-list
```

Expected output:

```bash
+-------------+-------------------+
| Target Name | SSL Profile ID(s) |
+-------------+-------------------+
| leaf1:57401 | Corp-Sec-A        |
|             | __default__       |
+-------------+-------------------+
```


### 4.2.3 CanGenerateCSR

On your host VM, run:

```bash
containerlab tools cert ca create
```

This creates 2 files, `ca.key` and `ca.pem`, a RSA-2048 key-pair and a CA certificate signed using SHA-256, which will be used to sign the CSR generated by the switch.

In order to verify the crypto suite we need to use, we can use the `openssl` command to view information about our CA certificate:

```bash
openssl x509 -in ca.pem -noout -text | head -n13
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 2019 (0x7e3)
        Signature Algorithm: sha256WithRSAEncryption    <------
        Issuer: C = Internet, L = Server, O = Containerlab, OU = Containerlab Tools, CN = containerlab.dev
        Validity
            Not Before: Nov 11 13:27:10 2026 GMT
            Not After : Nov  8 13:27:10 2036 GMT
        Subject: C = Internet, L = Server, O = Containerlab, OU = Containerlab Tools, CN = containerlab.dev
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)                  <------
```

Next, check if the switch can generate a Certificate Signing Request (CSR) that fits this requirement. If it can, we avoid generating certificates (and more importantly, private keys) outside the switch and transferring them over. The switch-generated CSR's common name (CN) will be `leaf1` and we will use the crypto suite `CSRSUITE_X509_KEY_TYPE_RSA_2048_SIGNATURE_ALGORITHM_SHA_2_256`.

```bash
gnsic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure certz can-gen-csr --cn leaf1 --csr-suite CSRSUITE_X509_KEY_TYPE_RSA_2048_SIGNATURE_ALGORITHM_SHA_2_256
```

Expected output:

```bash
+-------------+------------------+
| Target Name | Can Generate CSR |
+-------------+------------------+
| leaf1:57401 | true             |
+-------------+------------------+
```

We confirmed that the switch can generate a CSR.

### 4.2.4 Generate CSR

Next, we ask the switch to generate a CSR, get it signed and install it back on the switch, all with a single `gnsic` command.  
This uses the Certz Rotate RPC.

We will also add the `leaf1` DNS hostname and management IP into the SAN field of the certificate.

```bash
gnsic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure certz rotate --cn leaf1 --dns leaf1 --ca-cert ca.pem --ca-key ca.key --csr-suite CSRSUITE_X509_KEY_TYPE_RSA_2048_SIGNATURE_ALGORITHM_SHA_2_256 --id Corp-Sec-A --version 2 --san-ip-address "172.20.20.2" 
```

Expected output:

```bash
INFO[0000] leaf1:57401: can generate CSR                
INFO[0000] leaf1:57401: sending Generate CSR: ssl_profile_id:"Corp-Sec-A" generate_csr:{params:{csr_suite:CSRSUITE_X509_KEY_TYPE_RSA_2048_SIGNATURE_ALGORITHM_SHA_2_256 common_name:"leaf1" san:{ips:"172.20.20.2"}}} 
<--snip-->
INFO[0000] leaf1:57401: returned CSR:
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject: CN=leaf1
        Subject Public Key Info:
            Public Key Algorithm: RSA
                Public-Key: (2048 bit)
<--snip-->
-----END CERTIFICATE REQUEST----- 
INFO[0000] leaf1:57401: sending upload request: ssl_profile_id:"Corp-Sec-A" certificates:{entities:{version:"2" created_on:1794404204 certificate_chain:{certificate:{type:CERTIFICATE_TYPE_X509 encoding:CERTIFICATE_ENCODING_PEM raw_certificate:"-----BEGIN CERTIFICATE-----<--snip-->-----END CERTIFICATE-----\n"}}}} 
INFO[0000] leaf1:57401: upload response: certificates:{} 
INFO[0000] leaf1:57401: sending finalize request
```

The output above is shortened to show only the relevant parts. We can see the CSR that is generated by the switch, the CSR is signed and the resulting certificate is uploaded and installed on the switch.

### 4.2.5 TLS Profile Verification

Verify that the new TLS profile is configured with these signed certificates. We will use gNMI Get RPC for this purpose.

```bash
gnmic -a leaf1 -u admin -p NokiaSrl1! --skip-verify get --path /system/tls/profile[name=Corp-Sec-A] --encoding json_ietf
```

Expected output:

```json
[
  {
    "source": "leaf1",
    "timestamp": 1794404890040064605,
    "time": "2026-11-11T13:48:10.040064605Z",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-tls:tls/profile[name=Corp-Sec-A]",
        "values": {
          "srl_nokia-system:system/srl_nokia-tls:tls/profile": {
            "authenticate-client": false,
            "certificate": "-----BEGIN CERTIFICATE-----<snip>-----END CERTIFICATE-----\n",
            "cipher-list": [
              "srl_nokia-tls:ecdhe-ecdsa-aes256-gcm-sha384",
              "srl_nokia-tls:ecdhe-ecdsa-aes128-gcm-sha256",
              "srl_nokia-tls:ecdhe-rsa-aes256-gcm-sha384",
              "srl_nokia-tls:ecdhe-rsa-aes128-gcm-sha256"
            ],
            "dynamic": true,
            "expiration": "2036-11-08T13:46:49.000Z",
            "expired": false,
            "key": "$aes1$AW6PypSrmgvNx28=$<snip>>",
            "relaxed-crl-verification": true,
            "srl_nokia-gnsi-certz:certz": {
              "certificate": {
                "created-on": "2026-11-11T13:46:49.000Z",
                "version": "2"
              },
              "ssl-profile-id": "Corp-Sec-A"
            },
            "valid-after": "2026-11-11T12:46:49.000Z"
          }
        }
      }
    ]
  }
]
```

### 4.2.6 gNMI Set

The new TLS profile is now ready to be used. Let's update the secure gRPC server `mgmt` TLS profile to the new profile.

We will use gNMI Set RPC for this purpose.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update-path /system/grpc-server[name=mgmt]/tls-profile --update-value Corp-Sec-A
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "timestamp": 1794405045491601658,
  "time": "2026-11-11T13:50:45.491601658Z",
  "results": [
    {
      "operation": "UPDATE",
      "path": "system/grpc-server[name=mgmt]/tls-profile"
    }
  ]
}
```

### 4.2.7 gNMI Get Using Secure TLS

To verify that the new TLS profile is working, let's get the management port statistics using gNMI Get RPC using a secure TLS connection - that means no `--insecure` or `--skip-verify` here!  
We will have to supply the TLS CA as an additional parameter, since our temporary Containerlab certificate is not in the system root certificate store.

Because the SAN field had the IP address, we can both use `leaf1` and the IP address as a destination:

```bash
gnmic -a leaf1 -u admin -p NokiaSrl1! --tls-ca ca.pem get --path /interface[name=mgmt0]/statistics --encoding json_ietf

gnmic -a 172.20.20.2 -u admin -p NokiaSrl1! --tls-ca ca.pem get --path /interface[name=mgmt0]/statistics --encoding json_ietf
```

## Next Section: [gRIBI Service](/gribi/README.md)
