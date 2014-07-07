#!/bin/bash -x

mydir=$(dirname $(readlink -f $0))
mkdir ~/.juju
sed -e "s/@BOOTSTRAP_IP@/$BOOTSTRAP_IP/" $mydir/environments.yaml > ~/.juju/environments.yaml
juju bootstrap

if [ -n "$MACHINE_IPS" ]; then
    for machine_ip in $MACHINE_IPS; do
        juju add-machine ssh:$machine_ip
    done
else
    sleep 10
fi
