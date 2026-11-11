# 1 gNMI Use Cases

## 1.1 gNMI Capabilities

Let's start by checking the gNMI capabilities of the SR Linux device with the **gNMI Capabilities** RPC.

It also confirms that gNMI is enabled on the device.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure cap
```

Expected output:

```yaml
gNMI version: 0.10.0
supported models:
  - urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring:ietf-netconf-monitoring, IETF NETCONF (Network Configuration) Working Group, 2010-10-04
  - urn:ietf:params:xml:ns:yang:ietf-yang-library:ietf-yang-library, IETF NETCONF (Network Configuration) Working Group, 2019-01-04
  - urn:nokia.com:srlinux:aaa:aaa:srl_nokia-aaa, Nokia, 2026-07-31
  - urn:nokia.com:srlinux:aaa:aaa-password:srl_nokia-aaa-password, Nokia, 2026-07-31
  <---truncated--->
  supported encodings:
  - JSON_IETF
  - PROTO
  - ASCII
  <---truncated--->
```

## 1.2 gNMI Get

The **gNMI Get** RPC retrieves the running configuration or operational state of the device.

The lab startup configuration deployed by Containerlab already includes all interfaces.  
Let's verify the configuration of the interface on `leaf1` facing `spine`, `ethernet-1/1`!

To find the gNMI XPath of an object, use the [Nokia YANG Browser](https://yangbrowser.nokia.com/srlinux), where you can search for any configuration or state object that you might be looking for.

You can also get the gNMI XPath of an object from the SR Linux CLI. 

First, navigate to the object's context in the CLI. For example, on `leaf1`:

```bash
interface ethernet-1/1
```

Then run the command below to get the gNMI path to use in the request.

```bash
pwc xpath
```

Expected output:

```
/interface[name=ethernet-1/1]
```

The XPath expression here consists of the root (`/`), a single path element (`interface`) along with a key and value to select a specific element from a list (`[name=ethernet-1/1]`).  

Now that we have the path, let's retrieve the configuration of this interface using **gNMI Get** using `gnmic`.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure --encoding json_ietf get --path /interface[name=ethernet-1/1] --type config
```

Expected output:

```json
[
  {
    "source": "leaf1:57401",
    "timestamp": 1794318722711418294,
    "time": "2026-11-10T13:52:02.711418294Z",
    "updates": [
      {
        "Path": "srl_nokia-interfaces:interface[name=ethernet-1/1]",
        "values": {
          "srl_nokia-interfaces:interface": {
            "admin-state": "enable",
            "description": "To-Spine",
            "subinterface": [
              {
                "index": 0,
                "ipv4": {
                  "address": [
                    {
                      "ip-prefix": "192.168.10.2/31"
                    }
                  ],
                  "admin-state": "enable"
                },
                "ipv6": {
                  "address": [
                    {
                      "ip-prefix": "192:168:10::2/127"
                    }
                  ],
                  "admin-state": "enable"
                }
              }
            ]
          }
        }
      }
    ]
  }
]
```

### 1.2.1 gNMI Get for State

Next, let's retrieve only the operational state of the client-facing interface, `ethernet-1/10`, using **gNMI Get**. This comes from the state datastore, and thus we need to use `--type state`.

When using `gnmic`, the default value of `--type` is `state`, and thus can be omitted from the CLI flags.

To get the state gNMI XPath for operational state (oper-state), search for the leafs under interface context in the Nokia YANG Browser.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /interface[name=ethernet-1/10]/oper-state --encoding json_ietf
```

Expected output:

```json
[
  {
    "source": "leaf1:57401",
    "timestamp": 1794318891438326806,
    "time": "2026-11-10T13:54:51.438326806Z",
    "updates": [
      {
        "Path": "srl_nokia-interfaces:interface[name=ethernet-1/10]/oper-state",
        "values": {
          "srl_nokia-interfaces:interface/oper-state": "up"
        }
      }
    ]
  }
]
```

## 1.3 gNMI Set

The **gNMI Set** RPC makes configuration changes on the device.

There are several ways to update the configuration, and we will explore a few of them in this workshop.

### 1.3.1 Update

The `Update` option configures one leaf at a time.

We will start by configuring the interface MTU on the client-facing `ethernet-1/10` interface on `leaf1`.

Before we set the MTU, verify the current MTU from the state datastore using gNMI.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

The current MTU value should be 9232.

We can use the `--update` command to set a specific YANG leaf to a specific value (of specific type).  
This is expressed in the format `<path>:::<type>:::<value>`

Let's change the interface MTU facing the client to 4000!

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update /interface[name=ethernet-1/10]/mtu:::json:::4000
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "timestamp": 1794319041885587095,
  "time": "2026-11-10T13:57:21.885587095Z",
  "results": [
    {
      "operation": "UPDATE",
      "path": "interface[name=ethernet-1/10]/mtu"
    }
  ]
}
```

A **gNMI Set** request with `--update` acts as both a configuration modification and commit at the same time - it is not a good way to bulk change the configuration. 

Verify the new MTU value using the Get request used above - it should report 4000 now.

### 1.3.2 Update Path

Another way to specify a path and value is using `--update-path` and `--update-value` options. The type is deduced based on the `--encoding` option.

Modify the MTU of `ethernet-1/10` on `leaf1` to 3600 using these options.

```bash
gnmic -a leaf1 -u admin -p NokiaSrl1! --skip-verify set --update-path /interface[name=ethernet-1/10]/mtu --update-value 3600 --encoding json_ietf
```

Verify the current MTU using the Get request shown above.

### 1.3.3 Update File

To update multiple config objects at once, put the configuration in a file and send it to the device using the `--update-path` and `--update-file` options.

We will configure the `system0` loopback interface on all 3 devices using this method.

| Device  | System IP  |
|---------|------------|
| `leaf1` | 1.1.1.1/32 |
| `leaf2` | 2.2.2.2/32 |
| `spine` | 3.3.3.3/32 |

Prepared config files are located in your repo under [gnmi](../gnmi/) and are in `json` format.

> [!NOTE]
> If you are wondering how to prepare the configuration in `json` format:  
> SR Linux CLI has an option to display the configuration in `json` format. After an interface is configured, run the command below to display the interface configuration in `json` format. This can be copied to a file and used in the **gNMI Set** request.
>
> ```bash
> info interface ethernet-1/1 | as json
> ```

Let's push the system0 (loopback) interface configuration to all 3 devices. Make sure you are in the denog18-grpc-workshop directory before you run this command, as the file paths are relative.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update-path /interface[name=system0] --update-file gnmi/leaf1-system.cfg --encoding json_ietf
gnmic -a leaf2:57401 -u admin -p NokiaSrl1! --insecure set --update-path /interface[name=system0] --update-file gnmi/leaf2-system.cfg --encoding json_ietf
gnmic -a spine:57401 -u admin -p NokiaSrl1! --insecure set --update-path /interface[name=system0] --update-file gnmi/spine-system.cfg --encoding json_ietf
```

Expected output for `leaf1`:

```json
{
  "source": "leaf1:57401",
  "timestamp": 1794319351464766595,
  "time": "2026-11-10T14:02:31.464766595Z",
  "results": [
    {
      "operation": "UPDATE",
      "path": "interface[name=system0]"
    }
  ]
}
```

Verify the `system0` interface configuration using the **gNMI Get** RPC used earlier. You can also check the state of it and verify it's operational status.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure --encoding json_ietf get --path /interface[name=system0] --type config

gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure --encoding json_ietf get --path /interface[name=system0]
```

### 1.3.4 Replace File

To replace or overwrite an entire section of the config, specify the new config in a file and use the `--replace-path` and `--replace-file` options.

This is equivalent to deleting existing paths under the specified path, and configuring new ones, in one gNMI operation and commit.

To try this, we will replace the SNMP section with a new config that has a different community string value. If we were to just send this configuration via plain **gNMI Set**, the two community values would be both configured at the same time.

Verify the current SNMP configuration on `leaf1`:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /system/snmp --encoding json_ietf --type config
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747463297504455730,
    "time": "2025-05-17T02:28:17.50445573-04:00",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-system-snmp:snmp",
        "values": {
          "srl_nokia-system:system/srl_nokia-system-snmp:snmp": {
            "access-group": [
              {
                "community-entry": [
                  {
                    "community": "$aes1$AWBE6lIUmkA5sm8=$4iIHX6bSJuhf2Eqhbjb9QA==",
                    "name": "RO-Community"
                  }
                ],
                "name": "SNMPv2-RO-Community",
                "security-level": "no-auth-no-priv"
              }
            ],
            "network-instance": [
              {
                "admin-state": "enable",
                "name": "mgmt"
              }
            ]
          }
        }
      }
    ]
  }
]
```

First, try to use the `--update-path` and `--update-file` with the new SNMP configuration in [leaf1-snmp.cfg](leaf1-snmp.cfg) to see what it would do!

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update-path /system/snmp --update-file gnmi/leaf1-snmp.cfg --encoding json_ietf
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /system/snmp --encoding json_ietf --type config
```

Expected output:

```json
# ...
            "access-group": [
              {
                "community-entry": [
                  {
                    "community": "$aes1$AWBoO9e8ilsLlm8=$9HinnbGergrhz3rUbZF5oA==",
                    "name": "RO-Community"
                  }
                ],
                "name": "SNMPv2-RO-Community",
                "security-level": "no-auth-no-priv"
              },
              {
                "community-entry": [
                  {
                    "community": "$aes1$AWAdu4eU6gBcGG8=$5e7xP9EPZNMu4yweZDHwXA==",
                    "name": "denog"
                  }
                ],
                "name": "denog-snmpv2-community",
                "security-level": "no-auth-no-priv"
              }
            ],
# ...
```

Both SNMP communities got configured, and this is not what we wanted.

Instead, let's use the `--replace-path` and `--replace-file` options:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --replace-path /system/snmp --replace-file gnmi/leaf1-snmp.cfg --encoding json_ietf
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "timestamp": 1794319979110223035,
  "time": "2026-11-10T14:12:59.110223035Z",
  "results": [
    {
      "operation": "REPLACE",
      "path": "system/snmp"
    }
  ]
}
```

Now verify the SNMP config using the **gNMI Get** method.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /system/snmp --encoding json_ietf --type config
```

Expected output:

```json
[
  {
    "source": "leaf1:57401",
    "timestamp": 1794319996720334420,
    "time": "2026-11-10T14:13:16.72033442Z",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-system-snmp:snmp",
        "values": {
          "srl_nokia-system:system/srl_nokia-system-snmp:snmp": {
            "access-group": [
              {
                "community-entry": [
                  {
                    "community": "$aes1$AWAdu4eU6gBcGG8=$5e7xP9EPZNMu4yweZDHwXA==",
                    "name": "denog"
                  }
                ],
                "name": "denog-snmpv2-community",
                "security-level": "no-auth-no-priv"
              }
            ],
            "network-instance": [
              {
                "admin-state": "enable",
                "name": "mgmt"
              }
            ]
          }
        }
      }
    ]
  }
]
```

### 1.3.5 Update CLI File

Unlike SR Linux, some systems may not have 100% YANG coverage for all configuration objects. We can still use gNMI in this case, using the raw CLI commands push capability.  
This is what the `--update-cli-file` option is for.

Let's add a new SNMP community to the configuration, this time pushed with raw CLI.

The SNMP community configuration in flat CLI format is in [leaf1-cli.cfg](leaf1-cli.cfg).

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update-cli-file gnmi/leaf1-cli.cfg
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "timestamp": 1794320177778156632,
  "time": "2026-11-10T14:16:17.778156632Z",
  "results": [
    {
      "operation": "UPDATE",
      "path": "cli:/"
    }
  ]
}
```

Verify the updated SNMP communities using the **gNMI Get** RPC.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /system/snmp --encoding json_ietf --type config
```

Expected output:

```json
# ...
            "access-group": [
              {
                "community-entry": [
                  {
                    "community": "$aes1$AW7AMzB3ZV6WGm8=$vgPM0/LpqD5yIqafe8FzlA==",
                    "name": "from-cli"
                  }
                ],
                "name": "cli-snmpv2-community",
                "security-level": "no-auth-no-priv"
              },
            # ...
            ]
# ...
```
### 1.3.6 Commit Confirmed

Commit confirmed is a handy CLI feature when making risky changes. With it, the system rolls back automatically if the user does not accept or cancel the commit confirmed request before the timeout.

gNMIc (and gNMI by extension) supports this feature too.

To try this, we will change the MTU value of `ethernet-1/10` on `leaf1` from the current value of 3600 to 8000.

Verify the current value using Get method:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

Update the value to 8000 along with enabling commit confirm with a rollback duration of 5 minutes.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update /interface[name=ethernet-1/10]/mtu:::json:::8000 --commit-id mtu-8000 --commit-request --rollback-duration 5m
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1794383043226857323,
  "time": "2026-11-11T07:44:03.226857323Z",
  "results": [
    {
      "operation": "UPDATE",
      "path": "interface[name=ethernet-1/10]/mtu"
    }
  ]
}
```

Verify the new MTU value:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

The MTU value is now 8000.

When there is a commit confirm in progress, the system will not allow any new configuration changes via any management interface (CLI, Netconf, gRPC, JSON-RPC) until the active commit confirm is confirmed, cancelled or the rollback timer expires.

The status bar at the bottom of an active CLI session shows that a commit confirm is in progress and also shows the time remaining to accept or cancel the commit confirm. 

```bash
[commit confirmed (rollback in a minute)]
```

You will see the following error when you try to commit a new change while a commit confirm is ongoing.

```bash

target "leaf1:57401" set request failed: target "leaf1:57401" SetRequest failed: rpc error: code = Aborted desc = Cannot commit transaction (commit confirmed in progress)
```

You can see the details of an active commit confirm in the CLI with the following command:

```bash
info flat from state system configuration commit * | tail
```

Wait for the commit to time out - stretch your legs, shoot away some questions - and then verify the MTU again.

Since we did not accept the commit confirm, the system rolls back automatically when the rollback timer expires.

> [!TIP]
> If you don't want to wait, you can also **commit-cancel** the non-confirmed commit.
> You can do this either with the `--commit-cancel` CLI flag on gNMIc or with the SR Linux command
> `tools system configuration confirmed-reject persist-id <commit-id>`

The latest Get result shows the MTU back at the original value of 3600.

Let's do another MTU update to 7500 and this time we will accept the commit confirm.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update /interface[name=ethernet-1/10]/mtu:::json:::7500 --commit-id mtu-7500 --commit-request --rollback-duration 5m
```

Verify the new MTU value using Get:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

Confirm the commit before the rollback timer expires.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --commit-id mtu-7500 --commit-confirm
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "time": "1970-01-01T00:00:00Z"
}
```

The MTU change is now confirmed and will not get rolled back.

### 1.3.7 Delete

Our last option with the Set method is to delete a configuration element.

Let's delete the MTU from `ethernet-1/10` on `leaf1` so it reverts to the default MTU value.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --delete /interface[name=ethernet-1/10]/mtu
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "timestamp": 1794383485045204385,
  "time": "2026-11-11T07:51:25.045204385Z",
  "results": [
    {
      "operation": "DELETE",
      "path": "interface[name=ethernet-1/10]/mtu"
    }
  ]
}
```

Check the MTU value after the delete. It should now be the default MTU, 9232.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

To view the default value of any configuration leaf on SR Linux, refer to the YANG model - it's all in there!  
The easiest interactive tool to view this is the Nokia YANG Browser.

## 1.4 gNMI Subscribe

**gNMI Subscribe** RPC is the most commonly used gNMI RPC. It is what powers real-time streaming telemetry - and probably the first thing you thought of gRPC when you signed up for this workshop.

A **gNMI Subscribe** can be performed via `gnmic` using the `subscribe` or `sub` keyword.

We will try 3 different telemetry options during this workshop.

### 1.4.1 Once

Just like SNMP polling, you can poll a specific object over gNMI with the `ONCE` option of **gNMI Subscribe**.  

Let's get the output packet counter of interface `ethernet-1/1` on `leaf1` using this method.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode once
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794384233",
  "timestamp": 1794384233364724430,
  "time": "2026-11-11T08:03:53.36472443Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/1]/statistics/out-packets",
      "values": {
        "interface/statistics/out-packets": "2214"
      }
    }
  ]
}
{
  "sync-response": true
}
```

Nothing new so far.

### 1.4.2 Sample

If we need a continuous stream of the state of this path, we will use the `SAMPLE` option along with a specific interval.

This is the equivalent of a fixed polling interval with SNMP - albeit since it is so efficient, we can poll more regularly.

The following command streams the output packet counter value of `ethernet-1/1` every 5 seconds.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode stream --stream-mode sample --sample-interval 5s
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794384350",
  "timestamp": 1794384350751474134,
  "time": "2026-11-11T08:05:50.751474134Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/1]/statistics/out-packets",
      "values": {
        "interface/statistics/out-packets": "2218"
      }
    }
  ]
}
{
  "sync-response": true
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794384350",
  "timestamp": 1794384355751668549,
  "time": "2026-11-11T08:05:55.751668549Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/1]/statistics/out-packets",
      "values": {
        "interface/statistics/out-packets": "2218"
      }
    }
  ]
}
```


The streaming session can be stopped using `Ctrl+C`.

### 1.4.3 On-Change

In some cases, we only want a counter when the value has changed. For example, after a new interface is configured, the out packets will be 0 until a protocol and neighbor are established. There is no benefit in streaming continuous zeros.  
State leafs with a fixed set of states is similar - we don't need to check every 5 seconds whether an interface is still up, or a BGP neighbour is still established, but we do need to know when the oper-state and session-state changes, respectively.

This is what the `ON-CHANGE` option is for.  
With this option, the system only streams data when the value of the object changes, allowing for very efficient monitoring.

Let's stream the same out packets counter using this method.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode stream --stream-mode on-change
```

You will notice that very little data is getting streamed streamed, because the counter value does not change often.  
Another behaviour to take note of is that if you restart the streaming telemetry session, you will often get the same data back - this is so no matter when the subscription happens, even if no change has happened recently, the telemetry collector will also have the current state.

Keep the streaming session going and open another window to `leaf1`. Start a ping from `leaf1` to the `spine`-facing interface with an interval of 1 second.

```bash
ping 192.168.10.3 network-instance default -i 1
```

While ping is in progress, check the streaming output. There should be a continuous stream of the counter for every increment in the packet count.

Stop the ping using `Ctrl+C` and check the streaming output again. The stream slows down or stops, because the counter value is no longer changing.

Try running the ping again, but this time, let's lower the the ping interval to 0.1 seconds.

```bash
ping 192.168.10.3 network-instance default -i 0.1
```

Look at the streaming output - what interval do you see between each streaming telemetry update? It's still 1 second.  
Streaming telemetry updates for YANG leafs still happen at the speed at which the data model is updated by the network OS.

Stop the streaming session using `Ctrl+C`.

### 1.4.4 Targed-Defined

We can also let the network OS make the decision for us, whether sampling or on-change telemetry should be used for a given path. This is the **default** stream mode in gNMIc.

You can find out which stream mode will be used by looking at the YANG model - stream-mode is inherited by the children of parent YANG nodes, so you might need to look at parent nodes too.  
In SR Linux, if not otherwise specified, the target defined stream mode is ON_CHANGE.

Stream some telemetry of the operational state of interface `ethernet-1/10` first:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/10]/oper-state --mode stream 
```

...and notice how only the initial state of the interface is streamed, that is, until you turn down the interface `client1` `eth1`:

```bash
docker exec -it client1 ip link set dev eth1 down
```

Make sure to re-enable the interface by running:

```bash
docker exec -it client1 ip link set dev eth1 up
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794390797",
  "timestamp": 1794390797738477109,
  "time": "2026-11-11T09:53:17.738477109Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "up"
      }
    }
  ]
}
{
  "sync-response": true
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794390797",
  "timestamp": 1794390850084724320,
  "time": "2026-11-11T09:54:10.08472432Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "down"
      }
    }
  ]
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794390797",
  "timestamp": 1794390854613370295,
  "time": "2026-11-11T09:54:14.613370295Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "up"
      }
    }
  ]
}
```

Now, let's test a different state leaf, one that is sampled by default!  
If we take a look at [the YANG model for the interface statistics state container](https://github.com/nokia-steward/srlinux-yang-models/blob/v26.7/srlinux-yang-models/srl_nokia/models/interfaces/srl_nokia-interfaces.yang#L1690), you can see that the stream-mode is set on it - this is where the "target-defined" part comes from.

Not only the stream mode, but even the sampling interval can be suggested by the network OS.

Try to stream the number incoming packets on interface `ethernet-1/10` to see the difference:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/10]/statistics/in-packets --mode stream 
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794390667",
  "timestamp": 1794390667107002276,
  "time": "2026-11-11T09:51:07.107002276Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-packets",
      "values": {
        "interface/statistics/in-packets": "33"
      }
    }
  ]
}
{
  "sync-response": true
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794390667",
  "timestamp": 1794390672107337526,
  "time": "2026-11-11T09:51:12.107337526Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-packets",
      "values": {
        "interface/statistics/in-packets": "33"
      }
    }
  ]
}
```

We get a sampled update every 5 seconds - like the YANG model told us. :)

### 1.4.5 Streaming multiple paths

In previous telemetry query results, those of you with more perspectives as a programmer might have noticed that update_s_ is a list, and that for a returned metric, the path is also given.  
Why is this the case?

Well, let's try out something - instead of specifying that we are interested in the `in-packets` statistics leafs of `interface ethernet-1/10`, let's just focus on the `statistics` container.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/10]/statistics
```

Expected output:

```json
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794393782",
  "timestamp": 1794393782469559460,
  "time": "2026-11-11T10:43:02.46955946Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-packets",
      "values": {
        "interface/statistics/in-packets": "62"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-octets",
      "values": {
        "interface/statistics/in-octets": "4912"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-unicast-packets",
      "values": {
        "interface/statistics/in-unicast-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-broadcast-packets",
      "values": {
        "interface/statistics/in-broadcast-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-multicast-packets",
      "values": {
        "interface/statistics/in-multicast-packets": "62"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-discarded-packets",
      "values": {
        "interface/statistics/in-discarded-packets": "62"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-error-packets",
      "values": {
        "interface/statistics/in-error-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-fcs-error-packets",
      "values": {
        "interface/statistics/in-fcs-error-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-packets",
      "values": {
        "interface/statistics/out-packets": "2446"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-octets",
      "values": {
        "interface/statistics/out-octets": "513660"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-mirror-octets",
      "values": {
        "interface/statistics/out-mirror-octets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-unicast-packets",
      "values": {
        "interface/statistics/out-unicast-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-broadcast-packets",
      "values": {
        "interface/statistics/out-broadcast-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-multicast-packets",
      "values": {
        "interface/statistics/out-multicast-packets": "2446"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-discarded-packets",
      "values": {
        "interface/statistics/out-discarded-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-error-packets",
      "values": {
        "interface/statistics/out-error-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/out-mirror-packets",
      "values": {
        "interface/statistics/out-mirror-packets": "0"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/carrier-transitions",
      "values": {
        "interface/statistics/carrier-transitions": "4"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/interface-transitions",
      "values": {
        "interface/statistics/interface-transitions": "9"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/statistics/link-transitions",
      "values": {
        "interface/statistics/link-transitions": "0"
      }
    }
  ]
}
{
  "sync-response": true
}
```

A very nice property of gNMI is that a single query does not necessarily have to match for a single path...  
and a subscription can have multiple responses, which can contain many updates for many paths, allowing you to scale with both number of "keys" and amount of data per "keys" easily, without needing to make multiple queries.

This is also where the `sync-response: true` message comes into play - it lets the telemetry collector know that it has received all initial telemetry state. Any further updates after this will be on top of the initial state.

In this case, we looked at the `statistics` container. We can also try looking at containers of containers, like interface `ethernet-1/10` directly! Let the target defined subscription run for a bit.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-1/10]
```

Type some characters and press Return a few times every time you get new data, and then interrupt the streaming with `Ctrl+C`. What do you see?

That's right: part of the streamed paths are getting - and it's just the statistics for now, since those have a target defined streaming mode of sample every 5 seconds.

```bash
  "time": "2026-11-11T10:50:14.712027445Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-packets
...
  "time": "2026-11-11T10:50:19.712348673Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/statistics/in-packets",
```

Run the same command again, and in a new terminal, shut down the interface of the connected client, then turn it back up.

Expected output:

```json
# ... interface goes down ...
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794394294",
  "timestamp": 1794394300824551527,
  "time": "2026-11-11T10:51:40.824551527Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "down"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/oper-down-reason",
      "values": {
        "interface/oper-down-reason": "lower-layer-down"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/last-change",
      "values": {
        "interface/last-change": "2026-11-11T10:51:40.824Z"
      }
    }
  ]
}
# ... interface goes back up ...
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794394294",
  "timestamp": 1794394305771702274,
  "time": "2026-11-11T10:51:45.771702274Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "up"
      }
    },
    {
      "Path": "interface[name=ethernet-1/10]/last-change",
      "values": {
        "interface/last-change": "2026-11-11T10:51:45.771Z"
      }
    }
  ],
  "deletes": [
    "interface[name=ethernet-1/10]/subinterface[index=0]/oper-down-reason"
  ]
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794394294",
  "timestamp": 1794394305771750955,
  "time": "2026-11-11T10:51:45.771750955Z",
  "deletes": [
    "interface[name=ethernet-1/10]/oper-down-reason"
  ]
}
```

What did we learn here?

- **gNMI Subscribe** (and **gNMI Get**) work even on containers, and containers can contain further containers.
- Some paths of a subscription can be ON_CHANGE, and other SAMPLE at the same time.
- Results can be partially streamed - if multiple ON_CHANGE leaf paths are in the same subscription, only results for changed paths are returned after the initial sync.

### 1.4.6 Path wildcards

gNMI has another trick to pull out of its hat: we can even monitor multiple keys at once using _wildcards_. The wildcard character is an asterisk (*) and can be used inside keys, like `name` in case of interfaces.

Try to monitor the oper-state of all Ethernet interfaces, and flap `client1`'s `eth1` interface.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface[name=ethernet-*]/oper-state
```

Expected output after flapping the interface:

```json
# ...
      {
      "Path": "interface[name=ethernet-1/58]/oper-state",
      "values": {
        "interface/oper-state": "down"
      }
    }
  ]
}
{
  "sync-response": true
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794394763",
  "timestamp": 1794394992297428270,
  "time": "2026-11-11T11:03:12.29742827Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "down"
      }
    }
  ]
}
{
  "source": "leaf1:57401",
  "subscription-name": "default-1794394763",
  "timestamp": 1794394993399317732,
  "time": "2026-11-11T11:03:13.399317732Z",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/10]/oper-state",
      "values": {
        "interface/oper-state": "up"
      }
    }
  ]
}
```

If you would like to retrieve all elements of the list, the key-value selector can also be omitted, like so:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path /interface/oper-state
```

Expected output also contains other interfaces, like mgmt0:

```json
# ...
    {
      "Path": "interface[name=mgmt0]/oper-state",
      "values": {
        "interface/oper-state": "up"
      }
    },
# ...
```

Let's head on over to the next section, which tackles OpenConfig!

## Next Section: [OpenConfig](/openconfig/README.md)
