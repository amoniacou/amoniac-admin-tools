#!/bin/sh

[[ $# -ne 1 ]] && { echo "Usage: genkeys <username>"; exit 1; }

nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

LAST_IP=$(cat wg0.conf | grep "AllowedIPs" | awk '{print $3}' | awk -F/ '{print $1}' | sort | uniq | tail -n1)
USER="$1"
IP=$(nextip $LAST_IP)

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
echo ""

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
echo ""

echo "Restart tunnel with command:"
echo "wg-quick down wg0"
echo "wg-quick up wg0"
