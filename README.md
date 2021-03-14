ansible role: nfdump
=========

Deploy and configure nfdump, nfdump-sflow for ubuntu, debian.

Requirements
------------

Ansible 2.10

Role Variables
--------------

Name | Default Value | Description
---|---|---
`nfdump_nfcapd_dir` |  "/var/cache/nflow" | dir for netflow files
`nfdump_nfcapd_flags` | S: 1, T: -1,-2, t: 15, p: 9999, l: "{{ nfdump_nfcapd_dir }}" | non standard port 9999
`nfdump_sfcapd_dir` | "/var/cache/sflow" | dir for sflow files
`nfdump_sfcapd_flags` | S: 1, T: all, t: 15, p: 6343, l: "{{ nfdump_sfcapd_dir }}" | standard port 6343

Example Playbook
----------------

```yaml
---
- hosts: flow
  gather_facts: true
  connection: ssh
  roles:
    - v98765_nfdump
  environment:
    http_proxy: http://proxy.local:3128
    https_proxy: http://proxy.local:3128
```

License
-------

BSD
