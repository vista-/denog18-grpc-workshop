# 2 gNMI with OpenConfig Models

OpenConfig is a standards-based, vendor-neutral way for configuring and retrieving state from Network Operating Systems (NOS). OpenConfig is standardized by [OpenConfig.net](https://www.openconfig.net/). OpenConfig communication is based on YANG models.

OpenConfig YANG models are published at [GitHub](https://github.com/openconfig/public).

Nokia SR Linux supports OpenConfig.

In this section, we will explore OpenConfig YANG configuration and state using CLI and gNMI.

## 2.1 OpenConfig in SR Linux

OpenConfig models can be used via CLI, Netconf, gRPC or JSON-RPC interfaces in SR Linux.

The SR Linux OpenConfig CLI is similar to the native CLI, and CLI features like commit, rollback, discard and commit confirmed are also supported in OpenConfig.

Here is a quick reference table for switching between SRL (SR Linux) and OC modes in the CLI.

| Model     | From Mode     | To Mode       | Command               |
|-----------|---------------|---------------|-----------------------|
| SRL       | Running       | Candidate     | `enter candidate`     |
| SRL       | Candidate     | Running       | `enter running`       |
| SRL       | Candidate     | State         | `enter state`         |
| SRL       | Running       | State         | `enter state`         |
| SRL to OC | SRL Running   | OC Running    | `enter oc`            |
| SRL to OC | SRL Running   | OC Candidate  | `enter oc candidate`  |
| SRL to OC | SRL Running   | OC State      | `enter oc state`      |
| OC to SRL | OC Running    | SRL Running   | `enter srl`           |
| OC to SRL | OC Running    | SRL Candidate | `enter srl candidate` |
| OC to SRL | OC Running    | SRL State     | `enter srl state`     |

In short, if you want to switch between the same mode on SRL and OC, use `enter srl` or `enter oc`.

If you want to switch to a different mode, then use the mode name (`running/candidate/state`) with the `enter` command.

The current mode is displayed on the first line of the CLI prompt:

```bash
--{ + oc state }--[  ]--
A:leaf1#
```

In this example output, we are in state mode using OpenConfig models. 

OpenConfig model support can be toggled on or off on SR Linux. In the startup-config we provide, it is enabled on all 3 devices. You can verify this by checking the following state leaf:

```bash
info flat from state system management openconfig
```

Expected output:

```bash
/ system management openconfig admin-state enable
/ system management openconfig oper-state up
```

## 2.2 gNMI Get with OpenConfig

All interfaces were configured using SR Linux commands when the lab was deployed. With the SR Linux OpenConfig implementation, you can see this config in OpenConfig format.

Let's start by checking this in the CLI.

Log in to leaf1 and change to OC running mode using:

```bash
enter oc
```

Then run the command below to see interface ethernet-1/1 configuration in OpenConfig format.

```bash
info flat interfaces interface ethernet-1/1
```

Expected output:

```bash
set / interfaces interface ethernet-1/1 config name ethernet-1/1
set / interfaces interface ethernet-1/1 config type ethernetCsmacd
set / interfaces interface ethernet-1/1 config description To-Spine
set / interfaces interface ethernet-1/1 config enabled true
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 config index 0
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv4 addresses address 192.168.10.2 config ip 192.168.10.2
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv4 addresses address 192.168.10.2 config prefix-length 31
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv4 config enabled true
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv6 addresses address 192:168:10::2 config ip 192:168:10::2
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv6 addresses address 192:168:10::2 config prefix-length 127
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv6 config enabled true
```

Now let's retrieve this same configuration with a gNMI Get RPC.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path openconfig:/interfaces/interface[name=ethernet-1/1] --encoding json_ietf --type config
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1794395724265347010,
    "time": "2026-11-11T11:15:24.26534701Z",
    "updates": [
      {
        "Path": "openconfig:/interfaces/interface[name=ethernet-1/1]",
        "values": {
          "interfaces/interface": {
            "config": {
              "description": "To-Spine",
              "enabled": true,
              "name": "ethernet-1/1",
              "type": "iana-if-type:ethernetCsmacd"
            },
            "subinterfaces": {
              "subinterface": [
                {
                  "config": {
                    "index": 0
                  },
                  "index": 0,
                  "openconfig-if-ip:ipv4": {
                    "addresses": {
                      "address": [
                        {
                          "config": {
                            "ip": "192.168.10.2",
                            "prefix-length": 31
                          },
                          "ip": "192.168.10.2"
                        }
                      ]
                    },
                    "config": {
                      "enabled": true
                    }
                  },
                  "openconfig-if-ip:ipv6": {
                    "addresses": {
                      "address": [
                        {
                          "config": {
                            "ip": "192:168:10::2",
                            "prefix-length": 127
                          },
                          "ip": "192:168:10::2"
                        }
                      ]
                    },
                    "config": {
                      "enabled": true
                    }
                  }
                }
              ]
            }
          }
        }
      }
    ]
  }
]
```

Next, let's get the OpenConfig out-packets counter for interface `ethernet-1/1`. This is part of the state of the switch.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path openconfig:/interfaces/interface[name=ethernet-1/1]/state/counters/out-pkts --encoding json_ietf
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1794395741008271139,
    "time": "2026-11-11T11:15:41.008271139Z",
    "updates": [
      {
        "Path": "openconfig:/interfaces/interface[name=ethernet-1/1]/state/counters/out-pkts",
        "values": {
          "interfaces/interface/state/counters/out-pkts": "658"
        }
      }
    ]
  }
]
```

## 2.3 gNMI Set with OpenConfig

> [!IMPORTANT]
> The configuration here builds on top of the one we previously applied during the gNMI section of this workshop.  
> If you have not applied the configuration from there yet, please do so before proceeding with this task.

All the gNMI Set methods we tried previously with SR Linux models are also valid with OpenConfig models.

Due to time constraints, we will not repeat them here.

When OpenConfig is not fully supported for every config element within a context, a mix of vendor specific (also called native) and openconfig models are used to complete the configuration.

As part of our fabric deployment, we configure the following next:

- BGP for underlay
- BGP for overlay between leafs
- Layer 2 EVPN-VXLAN between clients 1 and 3

Not all objects for these configurations are supported in OpenConfig, so we will use native Nokia models to cover the gaps.

We will use the gNMI Set RPC with the `--update-path` and `--update-file` options.

OpenConfig configuration files for all 3 devices are in [oc](../configs/oc/).

SR Linux configuration files are in [srl](../configs/srl/).

Before we push the configuration, verify that BGP is not configured in the default network-instance using gNMI Get.

For example, to check on leaf1:

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path openconfig:/network-instances/network-instance[name=*] --encoding json_ietf --type config
```

Now we can push the configuration, using a mix of OpenConfig and SR Linux models.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure set --update-path openconfig:/ --update-file configs/oc/leaf1-oc.cfg --update-path srl_nokia:/ --update-file configs/srl/leaf1-srl.cfg --encoding json_ietf
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1794395589572525789,
  "time": "2026-11-11T11:13:09.572525789Z",
  "results": [
    {
      "operation": "UPDATE",
      "path": "openconfig:/"
    },
    {
      "operation": "UPDATE",
      "path": "srl_nokia:/"
    }
  ]
}
```

Run the Get RPC used above to verify that BGP and MAC-VRF are now configured.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path openconfig:/network-instances/network-instance[name=*] --encoding json_ietf --type config
```

Complete the configuration on leaf2 and spine.

```bash
gnmic -a leaf2:57401 -u admin -p NokiaSrl1! --insecure set --update-path openconfig:/ --update-file configs/oc/leaf2-oc.cfg --update-path srl_nokia:/ --update-file configs/srl/leaf2-srl.cfg --encoding json_ietf

gnmic -a spine:57401 -u admin -p NokiaSrl1! --insecure set --update-path openconfig:/ --update-file configs/oc/spine-oc.cfg --update-path srl_nokia:/ --update-file configs/srl/spine-srl.cfg --encoding json_ietf
```

With the configuration that we pushed, the BGP neighbor sessions should come up and start advertising the routes.

Let's verify this using gNMI Get.

As an example, let's verify the status of BGP neighbor `2.2.2.2` on leaf1 using SR Linux model.

> [!NOTE]
> Wait for a minute for BGP to establish the sessions.

To reduce the output, we will use the `depth` option supported in gNMIc.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path /network-instance[name=default]/protocols/bgp/neighbor[peer-address=2.2.2.2] --encoding json_ietf --depth 1
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1794395870613626184,
    "time": "2026-11-11T11:17:50.613626184Z",
    "updates": [
      {
        "Path": "srl_nokia-network-instance:network-instance[name=default]/protocols/srl_nokia-bgp:bgp/neighbor[peer-address=2.2.2.2]",
        "values": {
          "srl_nokia-network-instance:network-instance/protocols/srl_nokia-bgp:bgp/neighbor": {
            "admin-state": "enable",
            "advertised-capabilities": [
              "ROUTE_REFRESH",
              "4-OCTET_ASN",
              "MP_BGP",
              "GRACEFUL_RESTART"
            ],
            "established-transitions": "1",
            "last-established": "2025-07-02T08:49:24.800Z",
            "last-event": "recvOpen",
            "last-state": "active",
            "local-preference": 100,
            "maintenance-group": "",
            "next-hop-self": false,
            "peer-as": 65500,
            "peer-group": "evpn",
            "peer-router-id": "2.2.2.2",
            "peer-type": "ibgp",
            "received-afi-safi": [
              "srl_nokia-common:evpn"
            ],
            "received-capabilities": [
              "ROUTE_REFRESH",
              "4-OCTET_ASN",
              "MP_BGP",
              "GRACEFUL_RESTART"
            ],
            "received-end-of-rib": [
              "srl_nokia-common:evpn"
            ],
            "route-flap-damping": false,
            "sent-end-of-rib": [
              "srl_nokia-common:evpn"
            ],
            "session-state": "established",
            "under-maintenance": false
          }
        }
      }
    ]
  }
]
```

The Layer 2 EVPN should be up, so you should be able to ping from Client 1 to Client 3.

Log in to Client 1:

```bash
docker exec -it client1 bash
```

and run a ping to Client 3:

```bash
ping -c 3 172.16.10.60
```

## 2.4 gNMI Subscribe with OpenConfig

gNMI Subscribe for OpenConfig Streaming Telemetry works the same way as with the SR Linux models.

We will try the ON_CHANGE option in this section with OpenConfig models.

Let's stream the output packets counter on `leaf1`'s `ethernet-1/1` interface using the `on-change` stream-mode option.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure sub --path openconfig:/interfaces/interface[name=ethernet-1/1]/state/counters/out-pkts --mode stream --stream-mode on-change
```

Because we are using the on-change option, we will only see an output when the counter value changes.

On another window, run the ping from Client 1 to Client 3 as shown in previous section.

Check that the streaming session now shows an output for each counter increment.

Stop the ping and the streaming session using `Ctrl+C`.

## Next Section: [gNOI Service](/gnoi/README.md)
