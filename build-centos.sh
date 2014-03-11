#!/bin/bash -x
repoowner=nathwill
for size in small medium; do
  appliance-creator -c "centos-${size}.ks" -d -v -t /tmp \
     -o "/tmp/centos-${size}" --name "centos-${size}" --release 6 \
     --format=qcow2 && 
  virt-tar-out -a "/tmp/centos-${size}/centos-${size}/centos-${size}-sda.qcow2 / - > "centos-${size}.tar"
done
