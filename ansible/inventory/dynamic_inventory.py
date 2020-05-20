#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import argparse
import copy
import json
import sys


"""
The purpose of this is solely so that I can create a dynamic version later,
using a service registry like Consul or something.
"""


default_item = {"children":[], "hosts":[], "vars":{}}
_meta = {"hostvars": {}}


empty_meta = copy.deepcopy(_meta)

# May want to consider squashing almost all of this. It is not necessary.
# Inventory is SOLELY a hosts file. Chip arch, OS, and everything else
# can be derived from facts gathering and written into playbooks. Putting
# anything more in here than you need to is an anti-pattern.


pi0_addresses =         ["192.168.1.19", "192.168.1.33", "192.168.1.52", "192.168.1.63", "192.168.1.81", "192.168.1.203", "192.168.1.227"]
pi2_addresses =         ["192.168.1.129"]
pi3_addresses =         ["192.168.1.242"]
pi4_addresses =         ["192.168.1.135"]
odroidc2_addresses =    ["192.168.1.136"]
vagrant_addresses = ["127.0.0.1"]

pi0 = copy.deepcopy(default_item)
pi2 = copy.deepcopy(default_item)
pi3 = copy.deepcopy(default_item)
pi4 = copy.deepcopy(default_item)
odroidc2 = copy.deepcopy(default_item)
vagrant = copy.deepcopy(default_item)

pis = copy.deepcopy(default_item)
armv6 = copy.deepcopy(default_item)
armv7 = copy.deepcopy(default_item)
armv8 = copy.deepcopy(default_item)
alarm_hosts = copy.deepcopy(default_item)

k8s_masters = copy.deepcopy(default_item)
k8s_workers = copy.deepcopy(default_item)
k8s_hosts = copy.deepcopy(default_item) # Both masters and workers

pi0["hosts"].extend(pi0_addresses)
pi2["hosts"].extend(pi2_addresses)
pi3["hosts"].extend(pi3_addresses)
pi4["hosts"].extend(pi4_addresses)
odroidc2["hosts"].extend(odroidc2_addresses)
vagrant["hosts"].extend(vagrant_addresses)

pis["children"].extend(["pi0","pi2","pi3","pi4"])
armv6["children"].extend(["pi0"])
armv7["children"].extend([])
armv8["children"].extend(["pi2","pi3","pi4"])
alarm_hosts["children"].extend(["pi0","pi2","pi3","pi4","odroidc2"])

k8s_masters["children"].extend(["pi4"])
k8s_workers["children"].extend(["pi0","pi2","pi3","odroidc2"])
k8s_hosts["children"].extend(["k8s_masters", "k8s_workers"])


list_dict = {
                "_meta":_meta,

                "pi0":pi0,
                "pi2":pi2,
                "pi3":pi3,
                "pi4":pi4,
                "odroidc2":odroidc2,

                "vagrant":vagrant,

                "pis":pis,
                "armv6":armv6,
                "armv7":armv7,
                "armv8":armv8,
                "alarm_hosts":alarm_hosts,

                "k8s_masters":k8s_masters,
                "k8s_workers":k8s_workers,
                "k8s_hosts":k8s_hosts
             }


parser = argparse.ArgumentParser()
parser.add_argument('--list', action = 'store_true')
parser.add_argument('--host', action = 'store')
args = parser.parse_args()

if args.list:
    print(json.dumps(list_dict, indent=4))
elif args.host:
    try:
        temp_dict = {args.host:list_dict[args.host]}
    except:
        temp_dict = {"_meta":empty_meta}
    finally:
        print(json.dumps(temp_dict, indent=4))
else:
    print(json.dumps({"_meta":empty_meta}, indent=4))

sys.exit(0)

