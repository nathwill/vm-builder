
lang en_US.UTF-8
keyboard us
timezone --utc Etc/UTC

auth --useshadow --enablemd5
selinux --disabled
rootpw --lock --iscrypted locked

zerombr
clearpart --all --initlabel
part / --size 1024 --fstype ext4

# Repositories
repo --name=base --mirrorlist=http://mirrorlist.centos.org/?release=6&arch=$basearch&repo=os
repo --name=updates --mirrorlist=http://mirrorlist.centos.org/?release=6&arch=$basearch&repo=updates

reboot

# Package list.
%packages --excludedocs

bash
coreutils
centos-release
filesystem
findutils
grep
iproute
openssh-server
sed
setup
yum
passwd
shadow-utils

%end

%post --erroronfail

# create devices which appliance-creator does not
ln -s /proc/kcore /dev/core
mknod -m 660 /dev/loop0 b 7 0
mknod -m 660 /dev/loop1 b 7 1
rm -rf /dev/console
ln -s /dev/tty1 /dev/console

# prevent udevadm settle hanging
sed -i 's|.sbin.start_udev||' /etc/rc.sysinit
sed -i 's|.sbin.start_udev||' /etc/rc.d/rc.sysinit
chkconfig udev-post off

echo -n "Network fixes"
# initscripts don't like this file to be missing.
cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
EOF

# For cloud images, 'eth0' _is_ the predictable device name, since
# we don't want to be tied to specific virtual (!) hardware
rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

# simple eth0 config, again not hard-coded to the build hardware
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
EOF

# generic localhost names
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF

echo "Disabling UsePAM in sshd"
sed -i 's/^.*UsePAM.*$/UsePAM no/g' /etc/ssh/sshd_config

echo "Removing random-seed so it's not the same in every image."
rm -f /var/lib/random-seed

echo "Compressing cracklib."
gzip -9 /usr/share/cracklib/pw_dict.pwd

echo "Minimizing locale-archive."
localedef --list-archive | grep -v en_US | xargs localedef --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive
# this is really kludgy and will be fixed with a better way of building
# these containers
mv /usr/share/locale/en /usr/share/locale/en_US /tmp
rm -rf /usr/share/locale/*
mv /tmp/en /tmp/en_US /usr/share/locale/
mv /usr/share/i18n/locales/en_US /tmp
rm -rf /usr/share/i18n/locales/*
mv /tmp/en_US /usr/share/i18n/locales/
echo '%_install_langs C:en:en_US:en_US.UTF-8' >> /etc/rpm/macros.imgcreate

echo "Removing extra packages."
rm -vf /etc/yum/protected.d/*

echo "Removing boot, since we don't need that."
rm -rf /boot/*

echo "Cleaning old yum repodata."
yum clean all
rm -rf /var/lib/yum/yumdb/*
truncate -c -s 0 /var/log/yum.log

echo "rebuilding rpm db"
rm -f /var/lib/rpm/__*
rpm --rebuilddb

echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros

echo "(Don't worry -- that out-of-space error was expected.)"

%end
