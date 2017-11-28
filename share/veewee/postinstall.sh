#
# postinstall.sh
# Taken from https://github.com/jedi4ever/veewee/blob/master/templates/openSUSE-12.3-x86_64-NET_EN/postinstall.sh
#

date > /etc/vagrant_box_build_time
echo 'solver.allowVendorChange = true' >> /etc/zypp/zypp.conf
echo 'solver.onlyRequires = true' >> /etc/zypp/zypp.conf

# remove zypper package locks
rm -f /etc/zypp/locks

# install root user key
mkdir -pm 700 /root/.ssh
curl -Lo /root/.ssh/authorized_keys2 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub'
chmod 0600 /root/.ssh/authorized_keys2

# Comment AuthorizedKeysFile to use defaults allowing also authorized_keys2
sed -i '/AuthorizedKeysFile/s/^#*/#/' /etc/ssh/sshd_config

# update sudoers
echo -e "\nupdate sudoers ..."
echo -e "\n# added by veewee/postinstall.sh" >> /etc/sudoers
echo -e "vagrant ALL=(ALL) NOPASSWD: ALL\n" >> /etc/sudoers


# speed-up remote logins
echo -e "\nspeed-up remote logins ..."
echo -e "\n# added by veewee/postinstall.sh" >> /etc/ssh/sshd_config
echo -e "UseDNS no\n" >> /etc/ssh/sshd_config

# Avoid mac address configured into system, this results in getting
# eth1 instead of eth0 in virtualized environments sometimes.
# Anyway it won't be removed so we can check those rules.
mv /etc/udev/rules.d/70-persistent-net.rules{,.aytests}

# If eth0 is not configured, Vagrant will fail. So we need to make
# sure that it's configured. This hack is useful when network
# interface was renamed.
if [[ ! -f /etc/sysconfig/network/ifcfg-eth0 ]]; then
  cat > /etc/sysconfig/network/ifcfg-eth0 <<EOF
  BOOTPROTO='dhcp'
  STARTMODE='auto'
EOF
fi
# Switching back from ens* to eth* interfaces
mkdir -p /etc/systemd/network/
ln -s /dev/null /etc/systemd/network/99-default.link

# Make sure that everything's written to disk, otherwise we sometimes get
# empty files in the image
sync
