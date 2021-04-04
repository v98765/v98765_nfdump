#!/bin/bash

set -o allexport
source /etc/default/nfcapd
set +o allexport
[ -d "$NFLOW_DIR" ] || exit 1
cd $NFLOW_DIR

[ -d metrics ] || exit 1
[ -f /etc/networks_list ] || exit 1
if [ "$(whoami)" != "node-exp" ]; then
        echo "Script must be run as user: node-exp"
        exit 1
fi

nets_list=$(sipcalc -s 24 $(cat /etc/networks_list) | grep Net | awk '{print $3}' | sed 's~\.0$~ ~' | tr -d '\r\n')
nets_prefix=$(cat /etc/networks_list | sed 's~$~ ~' | tr -d '\r\n')
excl_prefix='10.0.0.0/8 192.168.0.0/16 172.16.0.0/12'
timewin1=$(date -d "-1 minutes" +%Y/%m/%d.%H:%M)
timewin2=$(date +%Y/%m/%d.%H:%M)


# check if nfcapd.current exists
filecurr=$(ls nfcapd.current*)
if ! [ -f "$filecurr" ] ; then
    echo 'file nfdump.current.* not found' 
    echo 'nf_file{nf="curr"} 0' > metrics/nf_file.prom
    echo 'nf_file{nf="archive"} 0' >> metrics/nf_file.prom
    echo 'nf_file{nf="1m"} 0' >> metrics/nf_file.prom
    rm -f /var/lib/node_exporter/nf_*.prom
    mv metrics/*.prom /var/lib/node_exporter/
    exit 1
fi

# work with current or find rotated file
sleep 1
timefind=$(date -d "-10 seconds" +%Y/%m/%d\ %H:%M:%S)
filertd=$(find . -name 'nfcapd.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' -type f -newermt "$timefind")
if [ -f "$filertd" ] ; then
    filecurr="$filertd"
    echo 'nf_file{nf="archive"} 1' > metrics/nf_file.prom
    echo 'nf_file{nf="curr"} 0' >> metrics/nf_file.prom
else
    echo 'nf_file{nf="curr"} 1' > metrics/nf_file.prom
    echo 'nf_file{nf="archive"} 0' >> metrics/nf_file.prom
fi

# create working file from large dump
rm -f metrics/nfdump.1m
nfdump -r $filecurr -t $timewin1-$timewin2 -w metrics/nfdump.1m \
'proto tcp or proto udp or proto icmp'
# sync time or file will be empty
if [ -f "metrics/nfdump.1m" ] ; then
    echo 'nf_file{nf="1m"} 1' >> metrics/nf_file.prom
else
    echo 'nf_file{nf="1m"} 0' >> metrics/nf_file.prom
    rm -f /var/lib/node_exporter/nf_*.prom
    mv metrics/*.prom /var/lib/node_exporter/
    exit 1
fi

# src data for nf_proto_uniq
nfdump -r metrics/nfdump.1m -N -q -A srcip,dstip,proto \
"not src ip in [ $excl_prefix ] and  dst ip in [ $nets_prefix ]" \
 -o "fmt:%da %pr" | sort | uniq -c > metrics/proto_uniq.nf

# src data for nf_proto_pkt
nfdump -r metrics/nfdump.1m -N -q -A dstip,proto \
"not src ip in [ $excl_prefix ] and  dst ip in [ $nets_prefix ]" \
 -o "fmt:%da %pr %pkt" > metrics/proto_pkt.nf

# total stats
nfdump -r metrics/nfdump.1m -I |  tr '[:upper:]' '[:lower:]' | tr -d ':' | egrep 'flows|packets|bytes' | sed 's~^~nf_total_~' > metrics/nf_total.prom

# zero to all ips

declare -A nf_proto_uniq
declare -A nf_proto_pkt

IFS=' '
for ntwrk in $nets_list ; do
  for hst in {1..254} ; do
    ip="${ntwrk}.${hst}"
    nf_proto_uniq["$ip,1"]='0'
    nf_proto_uniq["$ip,6"]='0'
    nf_proto_uniq["$ip,11"]='0'
    nf_proto_pkt["$ip,1"]='0'
    nf_proto_pkt["$ip,6"]='0'
    nf_proto_pkt["$ip,11"]='0'
  done
done

while read line ; do
    declare -a myline
    myline=($line)
    myline_uniq=${myline[0]}
    myline_ip=${myline[1]}
    myline_proto=${myline[2]}
    nf_proto_uniq["$myline_ip,$myline_proto"]=$myline_uniq
    unset myline
done < metrics/proto_uniq.nf

while read line ; do
    declare -a myline
    myline=($line)
    myline_ip=${myline[0]}
    myline_proto=${myline[1]}
    myline_pkt=${myline[2]}
    nf_proto_pkt["$myline_ip,$myline_proto"]=$myline_pkt
    unset myline
done < metrics/proto_pkt.nf

for key in ${!nf_proto_uniq[@]}; do
    IFS=','
    declare -a myline
    myline=($key)
    myline_ip=${myline[0]}
    myline_proto=${myline[1]}
    echo "nf_proto_uniq{ip=\"${myline_ip}\",proto=\"${myline_proto}\"} ${nf_proto_uniq[$key]}"
    unset myline
    IFS=' '
done > metrics/nf_proto_uniq.prom

for key in ${!nf_proto_pkt[@]}; do
    IFS=','
    declare -a myline
    myline=($key)
    myline_ip=${myline[0]}
    myline_proto=${myline[1]}
    echo "nf_proto_pkt{ip=\"${myline_ip}\",proto=\"${myline_proto}\"} ${nf_proto_pkt[$key]}"
    unset myline
    IFS=' '
done > metrics/nf_proto_pkt.prom

IFS=' '

mv metrics/*.prom /var/lib/node_exporter/
