# 3 gNOI Use Cases

In this section, we will explore gNOI services.

## 3.1 gNOI System Time

The System Time RPC can be used to get the current timestamp on the router.

This is often used to check connectivity between the client and the router and also to verify whether gNOI is operational on the router (similar to gNMI Capabilities).

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system time
```

Expected output:

```bash
+-------------+-----------------------------------------+---------------------+
| Target Name |                  Time                   |      Timestamp      |
+-------------+-----------------------------------------+---------------------+
| leaf1:57401 | 2025-05-19 13:09:12.601609856 -0400 EDT | 1747674552601609856 |
+-------------+-----------------------------------------+---------------------+
```

## 3.2 gNOI System Ping

The System Ping RPC can be used to initiate a ping on the router from a client.

For our test, let's ping the system loopback of `leaf2` from `leaf1`.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system ping --destination 2.2.2.2 --ns default --count 1 --wait 1s
```

Expected output:

```bash
56 bytes from 2.2.2.2: icmp_seq=1 ttl=63 time=56.420533ms
--- 2.2.2.2 ping statistics ---
1 packets sent, 1 packets received, 0.00% packet loss
round-trip min/avg/max/stddev = 56.421/56.421/56.421/0.000 ms
```

## 3.3 gNOI System Traceroute

Traceroute RPC can be used to trace the path to the destination using ICMP messages similar to a standard traceroute but executed remotely from a gNOI client.

Let us trace the path for `leaf2` loopback IP.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system traceroute --destination 2.2.2.2 --ns default --wait 1s
```

Expected output:

```bash
traceroute to 2.2.2.2 (2.2.2.2), 30 max hops, 56 byte packets
1 192.168.10.3 (192.168.10.3) 118.791864ms
2 2.2.2.2 (2.2.2.2) 127.56325ms
```

## 3.4 gNOI File Get

gNOI File service provides RPCs that are used to transfer files between the client and the router.

One of the use cases for gNOI File service is to perform configuration backups.

We will be using gNOI File Get RPC to do a remote configuration backup of leaf1.

First let's verify the configuration file exists. We will use the gNOI File Stat RPC for this purpose.

```
gnoic -a leaf1:57401 -u client1 -p client1 --insecure file stat --path /etc/opt/srlinux/config.json
```

Expected output:

```
+-------------+------------------------------+---------------------------+------------+------------+--------+
| Target Name |             Path             |       LastModified        |    Perm    |   Umask    |  Size  |
+-------------+------------------------------+---------------------------+------------+------------+--------+
| leaf1:57400 | /etc/opt/srlinux/config.json | 2025-01-31T17:40:01+02:00 | -rw-rw-r-- | -----w--w- | 102052 |
+-------------+------------------------------+---------------------------+------------+------------+--------+
```

The config file is present in the path. Now let's transfer the file our host VM. We will use gNOI File Get RPC.

```
gnoic -a leaf1:57401 -u client1 -p client1 --insecure file get --file /etc/opt/srlinux/config.json --dst .
```

Expected output:

```
INFO[0000] "leaf1:57400" received 64000 bytes           
INFO[0000] "leaf1:57400" received 38052 bytes           
INFO[0000] "leaf1:57400" file "/etc/opt/srlinux/config.json" saved 
```

Verify that the file is now present locally on your host.

```
ls -lrt etc/opt/srlinux/config.json
```

This action can be put inside a cron job and scheduled for daily backups.

## 3.5 gNOI File Put

gNOI File Put RPC can be used to transfer files to the router.

A configuration backup on a remote server can be transferred to SR Linux device using gNOI File Put RPC.

To test this, create a file on the host VM.

```bash
echo "config ospf bgp" > my-config.bkp
```

Next, let's transfer this file to `leaf1`.

```bash
gnoic -a leaf1:57401 -u client1 -p client1 --insecure file put --file my-config.bkp --dst /var/log/srlinux/my-config.bkp
```

Expected output:

```bash
INFO[0000] "leaf1:57401" sending file="my-config.bkp" hash 
INFO[0000] "leaf1:57401" file "my-config.bkp" written successfully 
```

Verify using File Stat RPC that the file exists on `leaf1`.

```bash
gnoic -a leaf1:57401 -u client1 -p client1 --insecure file stat --path /var/log/srlinux/my-config.bkp
```

Expected output:

```bash
+-------------+--------------------------------+---------------------------+------------+------------+------+
| Target Name |              Path              |       LastModified        |    Perm    |   Umask    | Size |
+-------------+--------------------------------+---------------------------+------------+------------+------+
| leaf1:57401 | /var/log/srlinux/my-config.bkp | 2025-05-19T03:30:38-04:00 | -rwxrwxrwx | -----w--w- | 16   |
+-------------+--------------------------------+---------------------------+------------+------------+------+
```

Now that the config backup is transferred, regular CLI process can be followed to restore this config. This is outside the scope of this activity.

## 3.6 gNOI Healthz

The Healthz RPC can be used to verify the health of the router components like line cards, fan tray etc.

Along with checking the health of the components, the RPC also generates a tech support file that can be used to troubleshoot in case the part is not healthy.

```bash
gnoic -a leaf1:57401 -u admin -p admin --insecure healthz check --path /platform/fan-tray[id=1]
```

Note - wait for a few seconds for the output as the system will be generating a Tech Support file.

Expected output:

```bash
+-------------+---------------------+-------------------------+--------------------+-----------------------------------------+---------------------+---------------+
| Target Name |         ID          |          Path           |       Status       |               Created At                |     Artifact ID     | Artifact Type |
+-------------+---------------------+-------------------------+--------------------+-----------------------------------------+---------------------+---------------+
| leaf1:57401 | 1749085078899992055 | platform/fan-tray[id=1] | STATUS_UNSPECIFIED | 2025-05-19 07:41:45.816390245 +0000 UTC | 1749085078894083190 | file          |
+-------------+---------------------+-------------------------+--------------------+-----------------------------------------+---------------------+---------------+
```

As this is a containerlab node, the health status is Unspecified.

#### EXAMPLE - Optional 3.7 gNOI automation using Ansible

Ansible modules can be used to automate gNOI or any other gRPC services.

Let's assume we want to check the reachability of multiple IP's from multiple switches in our sample topology. This can be automated using Ansible.

For our topology, we want to ping some IPs on `leaf2` from both `leaf1` and `spine`. We will also use a 3rd unknown IP to trigger a failure warning.

Create ansible inventory file on your VM:

```bash
cat << EOF >> ping-inventory.yml
all:
  children:
    nokia_switches:
      hosts:
        leaf1:
          ansible_host: leaf1
        spine:
          ansible_host: spine

      vars:
        # Common credentials for all switches in this group
        gnoi_port: 57400
        gnoi_user: admin
        gnoi_pass: $EVENT_PASSWORD
        
        # The universal ping list
        ping_targets:
          - { ip: "2.2.2.2", vrf: "default" }
          - { ip: "192.168.20.2", vrf: "default" }
          - { ip: "10.46.2.42", vrf: "default" }
EOF
```

Next, create the ansible playbook on your VM:

```bash

cat << EOF >> ping-playbook.yml
---
---
- name: gNOI Ping
  hosts: nokia_switches
  gather_facts: false
  connection: local

  tasks:
    - name: Run gNOI ping checks (JSON output)
      ansible.builtin.shell: >
        gnoic -a {{ ansible_host }}:{{ gnoi_port }}
        -u {{ gnoi_user }}
        -p {{ gnoi_pass }}
        --insecure
        system ping
        --destination {{ item.ip }}
        --ns {{ item.vrf }}
        --count 1
        --wait 1s
        --format json
      loop: "{{ ping_targets }}"
      loop_control:
        label: "{{ item.ip }}"
      register: raw_ping_results
      changed_when: false
      ignore_errors: true

    - name: Evaluate ping results
      ansible.builtin.set_fact:
        ping_report: >-
          {{ ping_report | default([]) + [{
            'ip': item.item.ip,
            'vrf': item.item.vrf,
            'ok': ((item.stdout | from_json).response.received | default(0)) >= 1
          }] }}
      loop: "{{ raw_ping_results.results }}"
      loop_control:
        label: "{{ item.item.ip }}"

    - name: Report ping results
      ansible.builtin.debug:
        msg: "[{{ inventory_hostname }}] {{ item.ip }} ({{ item.vrf }}) -> {{ 'OK' if item.ok else 'NOK' }}"
      loop: "{{ ping_report }}"
      loop_control:
        label: "{{ item.ip }}"

    - name: Fail the play if any ping check failed
      ansible.builtin.fail:
        msg: >-
          [{{ inventory_hostname }}] one or more ping checks failed:
          {{ ping_report | selectattr('ok', 'equalto', false) | map(attribute='ip') | list }}
      when: ping_report | selectattr('ok', 'equalto', false) | list | length > 0
EOF
```

Execute the playbook from your VM:

```bash
ansible-playbook -i ping-inventory.yml ping-playbook.yml
```

Expected output:

```bash
```
*This playbook uses Ansible's ansible.builtin.shell module to call gnoic directly. Ansible's role here is orchestration — looping over hosts and targets, capturing output, and reporting pass/fail — while gnoic performs the actual gNOI RPC call.* 
## 3.8 Software Upgrade using gNOI

This section is theory only as these RPCs cannot be implemented on a node in Containerlab.

The following commands can be used to automate software upgrade using gNOI RPCs.

To verify the current software verion on the device:

```bash
gnoic -a leaf1:57401 -u admin -p admin --insecure os verify
```

Expected output:

```bash
+-----------------------+-----------+---------------------+
|      Target Name      |  Version  | Activation Fail Msg |
+-----------------------+-----------+---------------------+
| leaf1:57401 | 23.7.2-84 |                     |
+-----------------------+-----------+---------------------+
```

To transfer a software image file to the device:

```bash
gnoic -a leaf1:57401 -u admin -p admin --insecure os install --version srlinux_23.10.1-218 --pkg ../23.10/srlinux-23.10.1-218.bin
```

In this commands, `version` refers to the software version of the image being transferred and `pkg` refers to the location of the image file on the host VM.

Expected output:

```bash
INFO[0000] target "leaf1:57401": starting Install stream 
INFO[0000] target "leaf1:57401": TransferProgress bytes_received:5242880 
INFO[0000] target "leaf1:57401": TransferProgress bytes_received:10485760 
INFO[0000] target "leaf1:57401": TransferProgress bytes_received:15728640 
...
INFO[0029] target "leaf1:57401": TransferProgress bytes_received:1179648000 
INFO[0029] target "leaf1:57401": TransferProgress bytes_received:1184890880 
INFO[0029] target "leaf1:57401": TransferProgress bytes_received:1190133760 
INFO[0030] target "leaf1:57401": sending TransferEnd 
INFO[0030] target "leaf1:57401": TransferProgress bytes_received:1195376640 
INFO[0030] target "leaf1:57401": TransferContent done... 
```

To activate a software image on the device:

```bash
gnoic -a leaf1:57401 -u admin -p admin --insecure os activate --version 23.10.1-218
```

Expected output:

```bash
INFO[0005] target "leaf1:57401" activate response "activate_ok:{}" 
```

Then verify the current software version using the `os verify` RPC used above.

## Next Section: [gNSI Service](https://github.com/srlinuxamericas/denog18-grpc/tree/main/gnsi)
