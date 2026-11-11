# 3 gNOI Use Cases

In this section, we will explore gNOI services.

## 3.1 gNOI System Time

The **gNOI System Time** RPC returns the current timestamp on the router.

This is often used to check connectivity between the client and the router and also to verify whether gNOI is operational on the router (similar to **gNMI Capabilities**).

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system time
```

Expected output:

```bash
+-------------+-----------------------------------------+---------------------+
| Target Name |                  Time                   |      Timestamp      |
+-------------+-----------------------------------------+---------------------+
| leaf1:57401 | 2026-11-10 12:32:28.587419852 +0000 UTC | 1794313948587419852 |
+-------------+-----------------------------------------+---------------------+
```

## 3.2 gNOI System Ping

The **gNOI System Ping** RPC lets a client start a ping on the router.

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

The **gNOI System Traceroute** RPC traces the path to the destination using ICMP messages, similar to a standard traceroute, but executed remotely from a gNOI client.

Let's trace the path for `leaf2` loopback IP.

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

The gNOI File service provides RPCs to transfer files between the client and the router.

One of the use cases for gNOI File service is to perform configuration backups.  
We will use the **gNOI File Get** RPC to perform a remote configuration backup from `leaf1`.

First, let's verify the configuration file exists. We will use the **gNOI File Stat** RPC for this purpose.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure file stat --path /etc/opt/srlinux/config.json
```

Expected output:

```bash
+-------------+------------------------------+----------------------+------------+------------+--------+
| Target Name |             Path             |     LastModified     |    Perm    |   Umask    |  Size  |
+-------------+------------------------------+----------------------+------------+------------+--------+
| leaf1:57401 | /etc/opt/srlinux/config.json | 2026-10-19T13:18:43Z | -rw-rw-r-- | -----w--w- | 126736 |
+-------------+------------------------------+----------------------+------------+------------+--------+
```

The config file is present in the path. Now let's transfer the file to our host VM. We will use the **gNOI File Get** RPC.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure file get --file /etc/opt/srlinux/config.json --dst .
```

Expected output:

```bash
INFO[0000] "leaf1:57401" received 64000 bytes           
INFO[0000] "leaf1:57401" received 38052 bytes           
INFO[0000] "leaf1:57401" file "/etc/opt/srlinux/config.json" saved 
```

Verify that the file is now present locally on your host:

```bash
ls -lrt etc/opt/srlinux/config.json
```

You can put this command in a cronjob for daily backups, just as one example for using **gNOI File Get**.

## 3.5 gNOI File Put

The **gNOI File Put** RPC transfers files to the router.

You can use it to transfer a configuration backup from a remote server to an SR Linux device.

To test this, create a file on the host VM.

```bash
echo "config ospf bgp" > my-config.bkp
```

Next, let's transfer this file to `leaf1`.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure file put --file my-config.bkp --dst /var/log/srlinux/my-config.bkp
```

Expected output:

```bash
INFO[0000] "leaf1:57401" sending file="my-config.bkp" hash 
INFO[0000] "leaf1:57401" file "my-config.bkp" written successfully 
```

Verify using **gNOI File Stat** that the file exists on `leaf1`.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure file stat --path /var/log/srlinux/my-config.bkp
```

Expected output:

```bash
+-------------+--------------------------------+----------------------+------------+------------+------+
| Target Name |              Path              |     LastModified     |    Perm    |   Umask    | Size |
+-------------+--------------------------------+----------------------+------------+------------+------+
| leaf1:57401 | /var/log/srlinux/my-config.bkp | 2026-11-10T12:34:40Z | -rwxrwxrwx | -----w--w- | 16   |
+-------------+--------------------------------+----------------------+------------+------------+------+
```

We can use the 

Now that the config backup is transferred, you can follow the regular CLI process to restore it. That is outside the scope of this activity.

## 3.6 gNOI Healthz

The **gNOI Healthz** RPC verifies the health of router components such as line cards and fan trays.

Besides checking the health of the components, the RPC also generates a tech support file you can use for troubleshooting if a part is not healthy.

```bash
gnoic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure healthz check --path /platform/fan-tray[id=1]
```

> [!NOTE]
> Wait a few seconds for the output, because the system is generating a Tech Support file before it can display the output.

Expected output:

```bash
+-------------+---------------------+-------------------------+--------------------+-----------------------------------------+---------------------+---------------+
| Target Name |         ID          |          Path           |       Status       |               Created At                |     Artifact ID     | Artifact Type |
+-------------+---------------------+-------------------------+--------------------+-----------------------------------------+---------------------+---------------+
| leaf1:57401 | 2316871566607349118 | platform/fan-tray[id=1] | STATUS_UNSPECIFIED | 2026-11-10 12:37:38.395522515 +0000 UTC | 2316871566596121938 | file          |
+-------------+---------------------+-------------------------+--------------------+-----------------------------------------+---------------------+---------------+
```

As this is a containerised SR Linux node, without real hardware, the health status of the fan tray is returned as Unspecified.

Using the returned artifact ID, you could now fetch the generated tech-support file using the following command:

```bash
gnoic -a leaf1:57401 -u admin -p NokiaSrl1! --insecure healthz artifact --id 1749085078894083190
```

> [!NOTE]
> The automated tech-support file generation and retrieval is a valid use-case. The analysis of the tech-suport file can only be done by the Nokia support organization. We cannot do anything with the retrieved tech-support file in this workshop. 

## 3.7 gNOI Automation Using Ansible (Optional Task)

You can use Ansible to automate gNOI or any other gRPC service operations.

Let's assume we want to check the reachability of multiple IPs from multiple switches in our sample topology. This can be automated using Ansible.

For our topology, we want to ping some IPs on `leaf2` from both `leaf1` and `spine`. We will also use a 3rd unknown IP to trigger a failure warning.

Create an Ansible inventory file on your VM:

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
        gnoi_port: 57401
        gnoi_user: admin
        gnoi_pass: "{{ lookup('env', 'EVENT_PASSWORD') }}"

        # The universal ping list
        ping_targets:
          - { ip: "2.2.2.2", vrf: "default" }
          - { ip: "192.168.20.2", vrf: "default" }
          - { ip: "10.46.2.42", vrf: "default" }
EOF
```

Next, create the Ansible playbook on your VM:

```bash
cat << EOF >> ping-playbook.yml
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
          {%- set out = [] -%}
          {%- for r in raw_ping_results.results -%}
          {%- set counts = (r.stdout | default('')) | regex_findall('"received": *"?([0-9]+)') | map('int') | list -%}
          {%- set _ = out.append({'ip': r.item.ip, 'vrf': r.item.vrf, 'ok': ((counts + [0]) | max) >= 1}) -%}
          {%- endfor -%}
          {{ out }}

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
$ ansible-playbook -i ping-inventory.yml ping-playbook.yml 

PLAY [gNOI Ping] *********************************************************************************************************************************************************************************************************

TASK [Run gNOI ping checks (JSON output)] ********************************************************************************************************************************************************************************
ok: [leaf1] => (item=2.2.2.2)
ok: [spine] => (item=2.2.2.2)
ok: [leaf1] => (item=192.168.20.2)
ok: [spine] => (item=192.168.20.2)
ok: [spine] => (item=10.46.2.42)
ok: [leaf1] => (item=10.46.2.42)

TASK [Evaluate ping results] *********************************************************************************************************************************************************************************************
ok: [leaf1]
ok: [spine]

TASK [Report ping results] ***********************************************************************************************************************************************************************************************
ok: [leaf1] => (item=2.2.2.2) => {
    "msg": "[leaf1] 2.2.2.2 (default) -> OK"
}
ok: [leaf1] => (item=192.168.20.2) => {
    "msg": "[leaf1] 192.168.20.2 (default) -> NOK"
}
ok: [spine] => (item=2.2.2.2) => {
    "msg": "[spine] 2.2.2.2 (default) -> NOK"
}
ok: [leaf1] => (item=10.46.2.42) => {
    "msg": "[leaf1] 10.46.2.42 (default) -> NOK"
}
ok: [spine] => (item=192.168.20.2) => {
    "msg": "[spine] 192.168.20.2 (default) -> OK"
}
ok: [spine] => (item=10.46.2.42) => {
    "msg": "[spine] 10.46.2.42 (default) -> NOK"
}

TASK [Fail the play if any ping check failed] ****************************************************************************************************************************************************************************
fatal: [leaf1]: FAILED! => {"changed": false, "msg": "[leaf1] one or more ping checks failed: ['192.168.20.2', '10.46.2.42']"}
fatal: [spine]: FAILED! => {"changed": false, "msg": "[spine] one or more ping checks failed: ['2.2.2.2', '10.46.2.42']"}

PLAY RECAP ***************************************************************************************************************************************************************************************************************
leaf1                      : ok=3    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0   
spine                      : ok=3    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0 
```

> [!NOTE]
> This playbook uses Ansible's ansible.builtin.shell module to call gNOIc directly. Ansible's role here is orchestration (looping over hosts and targets, capturing output and reporting pass/fail), while gNOIc performs the actual gNOI RPC call.

## 3.8 Software Upgrade Using gNOI

> [!IMPORTANT]
> This section is **theory only**, as these RPCs are not implemented on the containerised SR Linux simulator.
> Feel free to read this through to learn about using gNOI for software upgrades, or for later reference.

You can automate a software upgrade with the following gNOI RPCs.

To verify the current software version on the device:

```bash
gnoic -a HW-leaf1:57401 -u admin -p NokiaSrl1! --insecure os verify
```

Expected output:

```bash
+-----------------------+-----------+---------------------+
|      Target Name      |  Version  | Activation Fail Msg |
+-----------------------+-----------+---------------------+
|      HW-leaf1:57401   | 26.7.1    |                     |
+-----------------------+-----------+---------------------+
```

To transfer a software image file to the device:

```bash
gnoic -a HW-leaf1:57401 -u admin -p NokiaSrl1! --insecure os install --version srlinux_26.10.1 --pkg ../26.10/srlinux-26.10.1.bin
```

In these commands, `version` refers to the software version of the image being transferred and `pkg` refers to the location of the image file on the host VM.

Expected output:

```bash
INFO[0000] target "HW-leaf1:57401": starting Install stream 
INFO[0000] target "HW-leaf1:57401": TransferProgress bytes_received:5242880 
INFO[0000] target "HW-leaf1:57401": TransferProgress bytes_received:10485760 
INFO[0000] target "HW-leaf1:57401": TransferProgress bytes_received:15728640 
...
INFO[0029] target "HW-leaf1:57401": TransferProgress bytes_received:1179648000 
INFO[0029] target "HW-leaf1:57401": TransferProgress bytes_received:1184890880 
INFO[0029] target "HW-leaf1:57401": TransferProgress bytes_received:1190133760 
INFO[0030] target "HW-leaf1:57401": sending TransferEnd 
INFO[0030] target "HW-leaf1:57401": TransferProgress bytes_received:1195376640 
INFO[0030] target "HW-leaf1:57401": TransferContent done... 
```

To activate a software image on the device:

```bash
gnoic -a HW-leaf1:57401 -u admin -p NokiaSrl1! --insecure os activate --version 26.10.1
```

Expected output:

```bash
INFO[0005] target "HW-leaf1:57401" activate response "activate_ok:{}" 
```

Then check the software version again with **gNOI OS Verify** as used above.

## Next Section: [gNSI Service](/gnsi/README.md)
