#!/bin/bash
#
# generate text report for one ip-address
#
set -o allexport
source /etc/default/nfcapd
set +o allexport
[ -d "$NFLOW_DIR" ] || exit 1

cd $NFLOW_DIR
mkdir -p reports

echo 'enter ip address'
read varip
echo 'enter timerange as 2021/04/01.00:00-2021/04/03.00:00' 
read timewin

mkdir -p reports/${varip}

date
for m in $(find ./20* -maxdepth 1 -mindepth 1 -type d -name "[0-9][0-9]"); do
    reportdata=$( echo $m | tr -d './')
    set -x bash
    targetnfdump="reports/${varip}/nfdump.${reportdata}"
    nfdump -R $m "host ${varip}" -w $targetnfdump -t $timewin
    if [ -f "$targetnfdump" ] ; then
        nfdump -r $targetnfdump -q -o "fmt:%ts,%sa,%da" > reports/${varip}/${reportdata}.csv
    fi
    set +x bash
done
date
