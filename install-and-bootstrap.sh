#!/bin/bash -x

mkdir -p ~ubuntu/.ssh
cp id_rsa* ~ubuntu/.ssh
cat ~ubuntu/.ssh/id_rsa.pub >> ~ubuntu/.ssh/authorized_keys
cat >> ~ubuntu/.ssh/config <<EOF
StrictHostKeyChecking no
EOF
chown -R ubuntu:ubuntu ~ubuntu/.ssh
chmod 0600 ~ubuntu/.ssh/id_rsa
chmod 0644 ~ubuntu/.ssh/id_rsa.pub
chmod 0700 ~ubuntu/.ssh


export COMPUTE_TARGET

if type -p lava-sync > /dev/null; then
    lava-sync ssh-done

    lava-network broadcast eth0
    lava-network collect eth0

    if [ $(lava-group bootstrap | awk 'END { print NR }') != 1 ]; then
        echo "There should be exactly one bootstrap node!"
        exit 1
    fi

    export BOOTSTRAP_IP=$(lava-network query $(lava-group bootstrap) ipv4)
    export MACHINE_IPS=
    if [ -n "$(lava-group machine)" ]; then
        for host in $(lava-group machine); do
            MACHINE_IPS="$MACHINE_IPS${MACHINE_IPS:+ }$(lava-network query $host ipv4)"
        done
    fi

    sudo -u ubuntu ssh ubuntu@$BOOTSTRAP_IP true
    if [ -n "$MACHINE_IPS" ]; then
       for machine_ip in $MACHINE_IPS; do
           sudo -u ubuntu ssh ubuntu@$machine_ip true
       done
    fi
    if [ "$(lava-role)" = "bootstrap" ]; then
        is_bootstrap=yes
    else
        is_bootstrap=no
    fi
else
    export BOOTSTRAP_IP=$(ip route get 8.8.8.8 | awk 'match($0, /src ([0-9.]+)/, a)  { print a[1] }')
    is_bootstrap=yes
fi

if [ "$is_bootstrap" = "yes" ]; then
    apt-get install -y juju-core juju-deployer git lxc
    ./lxc-net.sh
    sleep 10
    sudo -u ubuntu -E -s <<EOF
mkdir ~/.juju
sed -e "s/@BOOTSTRAP_IP@/$BOOTSTRAP_IP/" ./environments.yaml > ~/.juju/environments.yaml
juju bootstrap

if [ -n "$MACHINE_IPS" ]; then
    for machine_ip in $MACHINE_IPS; do
        juju add-machine ssh:$machine_ip
    done
else
    sleep 10
fi
EOF
    cd ~ubuntu
    wget -O ./juju-script $LAVA_JUJU_SCRIPT_URL
    chmod u+x juju-script
    chown ubuntu:ubuntu juju-script
    sudo -u ubuntu ./juju-script
fi

if [ "$LAVA_SLEEP_FOR_ACCESS" = "yes" ]; then
    sleep 3600
fi

type -p lava-sync > /dev/null && lava-sync all-done
