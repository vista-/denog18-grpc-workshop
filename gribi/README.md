# 5 gRIBI Use Cases

gRIBI lets you inject routes into the FIB/RIB for real-time traffic steering.

In this workshop, we will demonstrate traffic re-routing with a simple use case.

## 5.1 Traffic Re-routing with gRIBI

### 5.1.1 Save and Destroy the Existing Lab

Save the existing lab, then destroy it:

```bash
sudo clab save
sudo clab des -a
```

### 5.1.2 Deploy the gRIBI Lab

Change to the `gribi` directory:

```bash
cd ~/denog18-grpc-workshop/gribi
```

Deploy the new lab topology:

```bash
sudo clab dep -c
```

The new lab is similar to the previous one, but it has no clients, and has an additional link between the 2 leafs.

![image](../images/denog18-gribi.svg)

The lab is deployed with all required configuration.

> [!NOTE]
> Wait a few seconds for BGP sessions to come up.

### 5.1.3 gNOI Traceroute

Find the path taken from `leaf1` to reach `2.2.2.2` on `leaf2`. To do this, we will perform a traceroute using the **gNOI System Traceroute** RPC.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system traceroute --destination 2.2.2.2 --ns default --wait 1s
```

Expected output:

```bash
traceroute to 2.2.2.2 (2.2.2.2), 30 max hops, 56 byte packets
1 192.168.10.3 (192.168.10.3) 326.604525ms
2 2.2.2.2 (2.2.2.2) 347.010499ms
```

The next hop from `leaf1` to reach `2.2.2.2` is via `spine`, because the direct link between the 2 leafs is not advertised in any routing protocol.

Next, we will inject a route on `leaf1` to redirect traffic going to `2.2.2.2` to use the direct link to `leaf2`.

Here's the gRIBI payload that we will push, you can find this in the current directory as `grib-input.yml`:

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
      prefix: 2.2.2.2/32
      nhg: 1
```

As a small explanation of this payload, here are the parameters set:
- The default network-instance to install a gRIBI route in, if not otherwise set
- The redundancy mode for gRIBI - in case of single-primary, only the primary client (outside of scope of SR Linux and this workshop) may modify the gRIBI routes
- The persistence mode - in our case, we will use preserve, in which case the gRIBI routes are retained even after the gRIBI client disconnects from the switch
- The acknowledgement type - in our case, the gRIBI operations will wait for the route to be installed both in the RIB and the FIB

The operations the payload must be also be ordered by the client:
- Next-hops must be created first - in our case, this is an IP address
- Next-hop groups must only be created after all referenced next-hop(s) are created
- The gRIBI route for a given destination prefix must only be created after all reference next-hop group(s) are created 

The election ID is related to the redundancy mode mentioned earlier, and is out of scope for this workshop.

### 5.1.4 Verify entries in the route table with gNMI Get

Before we push this route, let's verify the route table entries on `leaf1` using **gNMI Get**.  
Since the output would be normally quite detailed, we limit how deep **gNMI Get** will retrieve the information to 2 containers deep.  
Additionally, we will use grep to filter the long output, so we only see the prefixes and their route-type, and whether they are active or not.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding json_ietf --depth 2 | grep -E "prefix|active|type"
```

Expected Output:

```json
"active": true,
"ipv4-prefix": "1.1.1.1/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "2.2.2.2/32",
"route-type": "srl_nokia-common:bgp"
"active": true,
"ipv4-prefix": "172.16.10.0/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "172.16.10.0/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "192.168.10.2/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "192.168.10.2/32",
"route-type": "srl_nokia-common:host"
"active-routes": 6,
"active-routes-with-ecmp": 0,
```

If you would like to see the full output, try running the above command without the grep command at the end.

Before we push the route, let's get the currently installed gRIBI routes.

### 5.1.5 gRIBI Get

The **gRIBI Get** RPC can be used to retrieve any currently installed _gRIBI routes_ from the switch. The RPC requires two arguments: the network-instance and the address family table to look up.

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --ns default --aft ipv4
```

Expected output:

```bash
INFO[0000] target leaf1:57401: final get response:      
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":   
```

There are no gRIBI routes installed yet.

### 5.1.6 gRIBI Modify

Now, let's push the gRIBI route using the **gRIBI Modify** RPC. The route payload shown above is saved in a file [grib-input.yml](grib-input.yml).

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure modify --input-file grib-input.yml
```

Please note that the FIB programming might take a moment after the **gRIBI Modify** request goes through.

Expected output:

```bash
INFO[0000] trying to find variable file "grib-input_vars.yml" 
INFO[0000] sending request=params:{redundancy:SINGLE_PRIMARY persistence:PRESERVE ack_type:RIB_AND_FIB_ACK} to "leaf1:57401" 
INFO[0000] sending request=election_id:{high:1} to "leaf1:57401" 
INFO[0000] leaf1:57401
response: session_params_result: {} 
INFO[0000] leaf1:57401
response: election_id: {
  high: 1
} 
INFO[0000] target leaf1:57401 modify request:
operation: {
  id: 1
  network_instance: "default"
  op: ADD
  next_hop: {
    index: 1
    next_hop: {
      ip_address: {
        value: "172.16.10.1"
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0010] leaf1:57401
response: result: {
  id: 1
  status: FIB_PROGRAMMED
  timestamp: 1794415831706918074
} 
INFO[0010] target leaf1:57401 modify request:
operation: {
  id: 2
  network_instance: "default"
  op: ADD
  next_hop_group: {
    id: 1
    next_hop_group: {
      next_hop: {
        index: 1
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0010] target leaf1:57401 modify request:
operation: {
  id: 3
  network_instance: "default"
  op: ADD
  ipv4: {
    prefix: "2.2.2.2/32"
    ipv4_entry: {
      next_hop_group: {
        value: 1
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0010] leaf1:57401
response: result: {
  id: 2
  status: FIB_PROGRAMMED
  timestamp: 1794415831710166291
} 
INFO[0010] target leaf1:57401 modify stream done        
INFO[0010] leaf1:57401
response: result: {
  id: 3
  status: FIB_PROGRAMMED
  timestamp: 1794415831712544862
}
```

The operation is successful. Let's check out the result of our handiwork!

### 5.1.7 Verify installed gRIBI IPv4 routes using gRIBI Get

Using **gRIBI Get**, let's check out the gRIBI-installed routes once again in the default network-instance: 

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --ns default --aft ipv4
```

Expected output:

```bash
INFO[0000] target leaf1:57401: final get response: entry:{network_instance:"default" ipv4:{prefix:"2.2.2.2/32" ipv4_entry:{next_hop_group:{value:1}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":
entry: {
  network_instance: "default"
  ipv4: {
    prefix: "2.2.2.2/32"
    ipv4_entry: {
      next_hop_group: {
        value: 1
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
} 
```

The route reports as successfully installed and programmed in the RIB and the FIB.

### 5.1.8 Verify installed gRIBI next-hop groups using gRIBI Get

**gRIBI Get** can be used to also look up the installed next-hop groups (`nhg`):

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --ns default --aft nhg
```

Expected output:

```bash
INFO[0000] target leaf1:57401: final get response: entry:{network_instance:"default" next_hop_group:{id:1 next_hop_group:{next_hop:{index:1}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":
entry: {
  network_instance: "default"
  next_hop_group: {
    id: 1
    next_hop_group: {
      next_hop: {
        index: 1
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
} 
```

### 5.1.9 Verify installed gRIBI next-hops using gRIBI Get

Now, we are going to query the next-hops (`nh`) address family table using **gRIBI Get**:

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --ns default --aft nh
```

Expected output:

```bash
INFO[0000] target leaf1:57401: final get response: entry:{network_instance:"default" next_hop:{index:1 next_hop:{ip_address:{value:"172.16.10.1"}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":
entry: {
  network_instance: "default"
  next_hop: {
    index: 1
    next_hop: {
      ip_address: {
        value: "172.16.10.1"
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
} 
```


### 5.1.10 Verify routes in the routing-table with gNMI Get

Now let's verify the route table on `leaf1` and confirm that there is a route for `2.2.2.2/32`, which is the loopback IP on `leaf2`.

```bash
gnmic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding json_ietf --depth 2 | grep -E "prefix|active|type"
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
"active": true,
"ipv4-prefix": "1.1.1.1/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "2.2.2.2/32",
"route-type": "srl_nokia-common:gribi"
"active": true,
"ipv4-prefix": "172.16.10.0/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "172.16.10.0/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "192.168.10.2/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "192.168.10.2/32",
"route-type": "srl_nokia-common:host"
"active-routes": 6,
"active-routes-with-ecmp": 0,
</pre>
</details>

The route for `2.2.2.2` is now owned by gRIBI rather than BGP. This is because the gRIBI route preference value (6) is lower than the one of BGP (170), and is therefore more preferred.

### 5.1.11 gNOI Traceroute

Now it's time to check the path taken from `leaf1` to reach `2.2.2.2`. Repeat the traceroute command performed at the beginning of this activity and compare the next hops between the 2 outputs.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system traceroute --destination 2.2.2.2 --ns default --wait 1s
```

Expected output:

```bash
traceroute to 2.2.2.2 (2.2.2.2), 30 max hops, 56 byte packets
1 2.2.2.2 (2.2.2.2) 331.369923ms
```

`2.2.2.2` is now reachable over the direct link to `leaf2`.

### 5.1.12 gRIBI Flush

To wrap this section up, flush all gRIBI routes using the **gRIBI Flush** RPC:

```bash
gribic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure flush --ns default --override
```

Expected output:

```bash
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401": timestamp: 1747763792059403059
result: OK 
```

## Next Section (Optional): [Bonus Challenges](/z-bonus-challenge/README.md)

