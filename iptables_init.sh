#!/usr/bin/bash
 
# for DRYRUN, uncomment below
#action=echo
 
declare -A ALLOWED_SSH=(
  [141.142.236.22/31]="cerberus 2 & 4"
  [141.142.148.5]=cerberus1
  [141.142.148.24]=cerberus3
)
 
 
reset() {
  for cmd in iptables ip6tables; do
    $action $cmd -F #flush rules
    $action $cmd -X #delete chains
    $action $cmd -Z #flush counters
  done
}
 
 
fw_defaults() {
  for cmd in iptables ip6tables; do
    $action $cmd -P INPUT DROP
    $action $cmd -P FORWARD DROP
    $action $cmd -P OUTPUT ACCEPT
  done
}
 
 
fw_pre() {
  $action iptables -A INPUT -m state --state RELATED,ESTABLISHED -m comment --comment "for established connections" -j ACCEPT
  $action ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -m comment --comment "for established connections" -j ACCEPT
  $action iptables -A INPUT -i lo -m comment --comment "Accept all to lo interface for IPC" -j ACCEPT
  $action ip6tables -A INPUT -i lo -m comment --comment "Accept all IPv6 to lo interface for IPC" -j ACCEPT
  $action iptables -A INPUT -s 141.142.0.0/16 -p icmp -m comment --comment "Accept all ICMP for resilience to network problems for NCSA" -j ACCEPT
  $action iptables -A INPUT -s 10.142.0.0/16 -p icmp -m comment --comment "Accept all ICMP for resilience to network problems for NCSA internal" -j ACCEPT
  $action iptables -A INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment "Accept ICMP Echo to allow pings from outside" -j ACCEPT
  $action ip6tables -A INPUT -p ipv6-icmp -m comment --comment "Accept all IPv6 ICMP for resilience to network problems" -j ACCEPT
}
 
 
fw_post() {
  $action iptables -A INPUT -s 141.142.0.0/16 -m comment --comment "Reject from NCSA" -j REJECT
  $action iptables -A INPUT -s 10.142.0.0/16 -m comment --comment "Reject from NCSA internal" -j REJECT
  $action ip6tables -A INPUT -s 2620:0:0c80::/48 -m comment --comment "Reject the rest of IPv6 to INPUT from NCSA" -j REJECT
 
  $action iptables -A FORWARD -s 141.142.0.0/16 -m comment --comment "Reject from NCSA" -j REJECT
  $action iptables -A FORWARD -s 10.142.0.0/16 -m comment --comment "Reject from NCSA internal" -j REJECT
}
 
 
allow_ssh() {
  for _ip in "${!ALLOWED_SSH[@]}"; do
    $action iptables -A INPUT \
      -s "${_ip}" \
      -p tcp -m multiport --dports 22 \
      -m comment --comment "ssh from ${ALLOWED_SSH[$_ip]}" \
      -j ACCEPT
  done
}


disable_firewalld() {
	systemctl disable --now firewalld.service
	systemctl mask firewalld.service
}


enable_iptables() {
	yum -y install iptables-services ebtables ipset-service
	systemctl enable --now iptables.service
	systemctl enable --now ip6tables.service
	systemctl enable --now etables.service
	systemctl enable --now ipset.service
}
 
 
service_pre() {
  disable_firewalld
  enable_iptables
  for svc in iptables ip6tables etables ipset; do
    systemctl enable --now "$svc"
  done
}
 
 
service_post() {
  for svc in iptables ip6tables; do
    service "$svc" save
  done
}
 
 
service_pre
reset
fw_pre
allow_ssh
fw_post
fw_defaults
service_post
 
set -x
iptables -S
ip6tables -S
set +x
