# Bonus Challenges

Run these challenges on the gRIBI lab (see the [gRIBI section](../gribi/README.md)).  
Since the gRIBI routes are flushed at the end of the task, it is not necessary to complete the full activity, only the topology needs to be deployed.

## Bonus 1: Securing gNMI Service

By default, the switches allow the **gNMI Get**, **gNMI Set** and **gNMI Subscribe** RPCs to be performed.  
When setting up an external monitoring system, the user used for the gNMI-based streaming telemetry has no business being able to run **gNMI Set** RPCs, that is, to modify the switch configuration.

To secure our telemetry system, we should set up a separate user with restricted access!

### Create the Telemetry User

We need to first configure a new user `grclient1` on `leaf1` that will be used for streaming telemetry.

Log in to `leaf1` and run the following commands to create a role `gnmi-clients` and the user `grclient1`:

```bash
enter candidate private
set / system aaa authorization role gnmi-clients services [ gnmi ]
set / system aaa authentication user grclient1 password grclient1 role [ gnmi-clients ]
set / system configuration role gnmi-clients rule / action write
commit now
```

Your task is now to create a gNSI Authz policy to allow **gNMI Get**, **gNMI Subscribe** and deny **gNMI Set** to this user and role.

> [!TIP]
> Check the [gNSI](/gnsi/README.md) section if you need a hint here.

Here are the **gNMI Get**, **gNMI Set** and **gNMI Subscribe** commands to run from the VM in order to help you test your policy:

**gNMI Get**:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

**gNMI Set**:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify set --update /interface[name=ethernet-1/10]/mtu:::json:::4000
```

**gNMI Subscribe**:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode once
```

### Solution

Here's the gNSI Authz policy for reference:

<details>
<summary>Authz Solution</summary>

```json
{
  "name": "denog18-gnmi",
  "allow_rules": [
    {
      "name": "gnmi-access",
      "source": {
        "principals": [
          "grclient1", "gnmi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnmi.gNMI/Get",
          "/gnmi.gNMI/Subscribe"
        ]
      }
    }
  ],
  "deny_rules": [
    {
      "name": "gnmi-access",
      "source": {
        "principals": [
          "grclient1", "gnmi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnmi.gNMI/Set"
        ]
      }
    }
  ]
}
```

</details>

Here's the command to push this policy:

```bash
gnsic -a leaf1 -u admin -p NokiaSrl1! --skip-verify authz rotate --policy "{\"name\":\"denog18-gnmi\",\"allow_rules\":[{\"name\":\"gnmi-access\",\"source\":{\"principals\":[\"grclient1\",\"gnmi-clients\"]},\"request\":{\"paths\":[\"/gnmi.gNMI/Get\",\"/gnmi.gNMI/Subscribe\"]}}],\"deny_rules\":[{\"name\":\"gnmi-access\",\"source\":{\"principals\":[\"grclient1\",\"gnmi-clients\"]},\"request\":{\"paths\":[\"/gnmi.gNMI/Set\"]}}]}"
```

Verify the new policy is installed using **gNMI Get**:

```bash
gnmic -a leaf1 -u admin -p NokiaSrl1! --skip-verify get --path /system/aaa/authorization/authz-policy --encoding json_ietf
```

> [!NOTE]
> As gNSIc is in beta, you may have to run the policy install command multiple times until you see the policy in the verification output above.

After the policy is installed, try **gNMI Set**:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify set --update /interface[name=ethernet-1/10]/mtu:::json:::4000
```

and you should see the following error:

```bash
target "leaf1" set request failed: target "leaf1" SetRequest failed: rpc error: code = PermissionDenied desc = User 'grclient1' is not authorized to use rpc '/gnmi.gNMI/Set'
Error: one or more requests failed
```

## Bonus 2 Default Route Using gRIBI

Install a default route using gRIBI on `leaf1` with next-hop pointing to the direct interface to `leaf2`.

Get the list of current routes using **gNMI Get**:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding json_ietf --depth 2 | grep -E "prefix|active|type"
```

Make sure that there is no default route currently installed.

Install the default route using gRIBI.

### Solution

Here's the gRIBI payload for the default route.

```yaml
default-network-instance: default

params:
  redundancy: single-primary
  persistence: preserve
  ack-type: rib-fib

operations:
  - op: add
    election-id: 1:0
    nh:
      index: 1
      ip-address: 172.16.10.1

  - op: add
    election-id: 1:0
    nhg:
      id: 1
      next-hop:
        - index: 1

  - op: add
    election-id: 1:0
    ipv4:
      prefix: 0.0.0.0/0
      nhg: 1
```

Copy the payload to a file named `default-route.yml` and use gRIBIc to inject this route.

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure modify --input-file default-route.yml
```

Verify using **gNMI Get** that the default route is installed.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding json_ietf --depth 2 | grep -E "prefix|active|type"
```

Expected output:

```bash
"active": true,
"ipv4-prefix": "0.0.0.0/0",
"route-type": "srl_nokia-common:gribi"
```

To destroy the lab, run:

```bash
sudo clab des -a
```
