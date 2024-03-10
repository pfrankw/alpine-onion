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
apk add tor iptables

echo -e "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\n\nauto eth1\niface eth1 inet static\n\taddress 10.152.152.10\n\tnetmask 255.255.255.0" > /etc/network/interfaces
echo -e "VirtualAddrNetworkIPv4 10.192.0.0/10\nAutomapHostsOnResolve 1\nTransPort 10.152.152.10:9040\nDNSPort 10.152.152.10:5353" > /etc/tor/torrc
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/ip_forward.conf

iptables -F
iptables -t nat -F

iptables -P OUTPUT ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP

iptables -t nat -A PREROUTING -i eth1 -p udp --dport 53 -j REDIRECT --to-ports 5353
iptables -t nat -A PREROUTING -i eth1 -p tcp --syn -j REDIRECT --to-ports 9040

iptables -A OUTPUT -m owner --uid-owner $(id -u tor) -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -d 10.152.152.10 -p tcp --dport 9040 -j ACCEPT
iptables -A INPUT -d 10.152.152.10 -p udp --dport 5353 -j ACCEPT

rc-update add iptables
rc-service iptables save

rc-update add tor
rc-update del syslog boot

echo "Installation complete. Please reboot."
