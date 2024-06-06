#!/bin/ash

#enable community repo

cp /etc/apk/repositories /etc/apk/repositories.bak

for line in $(cat /etc/apk/repositories.bak);
do
        echo $line | grep community > /dev/null
        if [ $? == 0 ]; then
                echo $line | sed s/^#//g
        else
                echo $line
        fi
done > /etc/apk/repositories

apk update
apk add tor iptables nyx dhcp

echo -e "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\n\nauto eth1\niface eth1 inet static\n\taddress 10.152.152.10\n\tnetmask 255.255.255.0" > /etc/network/interfaces
echo -e "VirtualAddrNetworkIPv4 10.192.0.0/10\nAutomapHostsOnResolve 1\nTransPort 10.152.152.10:9040\nDNSPort 10.152.152.10:5353\nControlPort unix:/var/run/tor/control RelaxDirModeCheck" > /etc/tor/torrc
#echo -e "port=0\ndhcp-range=10.152.152.11,10.152.152.200,12h\ndhcp-option=option:router,10.152.152.10\ndhcp-option=option:dns-server,10.152.152.10\ndhcp-lease-max=150\ndhcp-leasefile=/var/lib/misc/dnsmasq.leases" > /etc/dnsmasq.conf
cat <<EOF > /etc/dhcp/dhcpd.conf
# Option definitions common to all supported networks...
option domain-name "example.org";
option domain-name-servers 10.152.152.10;

# Default lease time
default-lease-time 43200; # 12 hours in seconds

# Maximum lease time
max-lease-time 86400; # 24 hours in seconds

# The subnet and range of IP addresses to assign
subnet 10.152.152.0 netmask 255.255.255.0 {
  range 10.152.152.100 10.152.152.250;
  option routers 10.152.152.10;
}

# Specify the location of the DHCP lease file
lease-file-name "/var/lib/dhcp/dhcpd.leases";
EOF

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/ip_forward.conf

iptables -F
iptables -t nat -F

iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

iptables -t nat -A PREROUTING -i eth1 -p udp --dport 53 -j REDIRECT --to-ports 5353
iptables -t nat -A PREROUTING -i eth1 -p tcp --syn -j REDIRECT --to-ports 9040

# only tor user can exit
iptables -A OUTPUT -m owner --uid-owner $(id -u tor) -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# tor daemon
iptables -A INPUT -s 10.152.152.0/24 -d 10.152.152.10 -p tcp --dport 9040 -j ACCEPT
iptables -A INPUT -s 10.152.152.0/24 -d 10.152.152.10 -p udp --dport 5353 -j ACCEPT
# dhcp
iptables -A INPUT -s 0.0.0.0 -p udp --sport 68 -d 255.255.255.255 --dport 67 -j ACCEPT
iptables -A INPUT -s 0.0.0.0 -p udp --sport 68 -d 10.152.152.10 --dport 67 -j ACCEPT
iptables -A INPUT -s 10.152.152.0/24 -p udp --sport 68 -d 10.152.152.10 --dport 67 -j ACCEPT
iptables -A OUTPUT -s 10.152.152.10 -p udp --sport 67 -d 10.152.152.0/24 --dport 68 -j ACCEPT

rc-update add iptables
rc-service iptables save

rc-update add tor
rc-update del syslog boot

rc-update add dhcpd

echo "Installation complete. Please reboot."
