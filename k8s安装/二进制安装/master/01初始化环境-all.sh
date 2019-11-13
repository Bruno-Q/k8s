#!/bin/bash
# Initialize the machine. This needs to be executed on every machine.
# Add host domain name.
cat>/etc/hosts<<EOF
192.168.197.200 master
192.168.197.201 node1
EOF
# Modify related kernel parameters.
cat>/etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/kubernetes.conf>&/dev/null
# Turn off and disable the firewalld.
systemctl stop firewalld
systemctl disable firewalld
# Disable the SELinux.
sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config
# Disable the swap .
sed -i.bak 's/^.*swap/#&/g' /etc/fstab
# Reboot the machine.
reboot
