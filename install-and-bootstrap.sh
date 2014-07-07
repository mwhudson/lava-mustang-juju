#!/bin/bash -x

mydir=$(dirname $(readlink -f $0))

mkdir -p ~ubuntu/.ssh
cp $mydir/id_rsa* ~ubuntu/.ssh
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

    if [ "$(lava-group | sort  | awk '{ print $1}' | head -n1)" = "$(lava-self)" ]; then
        is_bootstrap=yes

        export BOOTSTRAP_IP=$(lava-network query $(lava-self) ipv4)
        export MACHINE_IPS=
        for host in $(lava-group | awk '{ print $1 }'); do
            if [ "$host" != "$(lava-self)" ]; then
                MACHINE_IPS="$MACHINE_IPS${MACHINE_IPS:+ }$(lava-network query $host ipv4)"
            fi
        done

        sudo -u ubuntu ssh ubuntu@$BOOTSTRAP_IP true
        if [ -n "$MACHINE_IPS" ]; then
            for machine_ip in $MACHINE_IPS; do
                sudo -u ubuntu ssh ubuntu@$machine_ip true
            done
        fi
    else
        is_bootstrap=no
    fi

else
    export BOOTSTRAP_IP=$(ip route get 8.8.8.8 | awk 'match($0, /src ([0-9.]+)/, a)  { print a[1] }')
    export MACHINE_IPS=
    is_bootstrap=yes
fi

if [ "$is_bootstrap" = "yes" ]; then
    apt-get install -y juju-core juju-deployer git lxc
    $mydir/lxc-net.sh
    sleep 10
    sudo -u ubuntu -E $mydir/bootstrap.sh
    if [ $# -gt 0 ]; then
        sudo -u ubuntu "$@"
    fi
fi

if [ "$LAVA_SLEEP_FOR_ACCESS" = "yes" ]; then
    echo "ssh to $(ip route get 8.8.8.8 | awk 'match($0, /src ([0-9.]+)/, a)  { print a[1] }')"
    sleep ${LAVA_SLEEP_DURATION-3600}
fi

type -p lava-sync > /dev/null && lava-sync all-done
