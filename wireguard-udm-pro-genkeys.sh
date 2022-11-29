#!/bin/sh

[[ $# -ne 2 ]] && { echo "Usage: genkeys <username> <ip>"; exit 1; }

USER="$1"
IP="$2"

umask 077
wg genkey | tee ${USER}.key | wg pubkey > ${USER}.pub
wg genpsk > ${USER}.psk

cat << EOF >> wg0.conf

[Peer]
PublicKey = `cat ${USER}.pub`
PresharedKey = `cat ${USER}.psk`
AllowedIPs = ${IP}/32
EOF

echo "Config for user"

cat << EOF
[Interface]
PrivateKey = `cat ${USER}.key`
Address = ${IP}/32
DNS = ${IP}

[Peer]
PublicKey = `cat server.pub`
PresharedKey = `cat ${USER}.psk`
AllowedIPs = 10.10.10.1/8, 172.16.1.0/24
Endpoint = $(ip a s eth8 | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2):51820

EOF

echo "Restart tunnel with command:"
echo "wg-quick down wg0"
echo "wg-quick up wg0"
