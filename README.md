AutoYaST Integration Tests
===========================

Test framework for running AutoYaST integration tests by using veewee,
 vagrant and pennyworth.

Features
--------

  * Building KVM images by using AutoYaST profiles.
  * Checking these KVM images with rspec tests.
  * Generating own installation ISOs with local built RPMs or the newest one from OBS.

Supported Scenarios
-------------------

These integration tests need to start virtual machines for their operation.
For that reason, support for hardware virtualization is vitally important.
Check it on your host system

    $ grep --only-matching '\(svm\|vmx\)' /proc/cpuinfo

Installation
------------

  1. Install packages [mkdud](http://software.opensuse.org/download.html?project=openSUSE%3AFactory&package=mkdud)
     and [mksusecd](http://software.opensuse.org/download.html?project=home%3Asnwint&package=mksusecd)
     from OBS.

       $ zypper install ./mkdud-*.rpm ./mksusecd-*.rpm

  2. Install `virt-install` package

       $ zypper install virt-install

  3. Unless you run tests as 'root', configure `sudo` in order to run the `mksusecd`,
     `systemctl start libvirtd` and `zypper in` commands as root.

     This will grant access to execute every command for user <username> as root without
     asking for password, unsecure

        echo '<username> ALL=NOPASSWD: ALL' >> /etc/sudoers

  4. Generate a ssh-key for vagrant (e.g. with ssh-keygen) unless you already have one.

  5. Install [Pennyworth](https://github.com/SUSE/pennyworth#installation) but instead
     of cloning the repository, install the
     [pennyworth-tool gem](https://rubygems.org/gems/pennyworth-tool/).
     An older version is necessary now because of an API change
     in `Pennyworth::VM#run_command`.

        $ gem install pennyworth-tool --no-format-executable --version "= 0.1.0"
        $ pennyworth setup

  6. Enable and start libvirt and configure default network and storage

        $ systemctl enable libvirtd
        $ systemctl start libvirtd
        $ virsh net-start default
        $ # if you want the default network to be started automatically.
        $ virsh net-autostart default
        $ virsh pool-define-as default dir - - - - /var/lib/libvirt/images
        $ virsh pool-start default
        $ virsh pool-autostart default

  7. Clone autoyast-integration-test repository and install needed GEMs

        $ git clone https://github.com/yast/autoyast-integration-test
        $ cd autoyast-integration-test
        $ bundle install

  8. If the host is running a firewall, you must permit connections from
     libvirt default network to host’s port 8888. For example, if you’re
     running SuSEfirewall2 and your libvirt default network is 192.168.122.0
     (you can check it on `/etc/libvirt/qemu/networks/default.xml`), you could
     add a custom rule to /etc/sysconfig/SuSEfirewall2 allowing incoming
     connections from 192.168.122.0/24 to TCP port 8888, e.g.:

        FW_SERVICES_ACCEPT_EXT="192.168.122.0/24,tcp,8888"

     After that, you must reboot your system to be sure everything works
     properly (libvirt iptables rules, ip forwarding, etc.).

  9. Only in Tumbleweed, you must update the vagrant-libvirt plugin:

        $ NOKOGIRI_USE_SYSTEM_LIBRARIES=true vagrant plugin install vagrant-libvirt

Running
-------

For a complete list of tasks, run:

    $ rake -T

To run the testsuite, use the `test` Rake task:

    $ rake test

This runs all tests defined in test/*.rb (e.g. test/tftp.rb):
* Building a KVM image by using the AutoYaST configuration file (e.g. tftp.xml)
      You can watch the installation by using `virt-manager`. The image is `autoyast`.
* Starting the built image.
  You can watch it by using `virt-manager`. The image is `vagrant_autoyast_vm`.
* Running rspec tests on this machine which are defined in e.g. test/tftp.rb.

To run only one single test use:

    $ rake test[<absolute_path_to_test_file>]

e.g. `rake test[/src/autoyast_test/test/sles12.rb]`

or you can also run any single script directly

    $ rspec [<absolute_path_to_test_file>]

To generate a new installation image based on SLES12 call:

    $ rake build_iso[sles12]

The process is defined in build_iso/sles12.rb:

* Fetching all RPMs (defined in build_iso/sles12.obs_packages) from OBS
* Fetching all local RPMs (defined in build_iso/sles12.local_packages)
* Fetching official SLES12 ISO
* Generating a new SLES12 ISO with this new RPM packages
* Copying new SLES12 ISO into test environment (directory kiwi/iso)

This new ISO image will be used for running tests in the future.

To use the official SLES12 ISO (default setting) for tests just call:

    $ rake build_iso[default]

Solving Problems
----------------

If you are experiencing *There was a problem opening a connection to libvirt:
libvirt is not a recognized compute provider* error, you might need to
downgrade gems 'fog' and 'fog' core to version 1.30 to 1.29

    $ gem list fog
    $ gem install fog --version 1.29
    $ gem uninstall fog --version 1.30
    $ gem install fog-core --version 1.29
    $ gem uninstall fog-core --version 1.30

Jenkins
-------

These AutoYaST integration tests are running on a SUSE jenkins node:

http://river.suse.de/job/autoyast-integration-test/
