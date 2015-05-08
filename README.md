AutoYaST Integration Tests
===========================

Test framework for running AutoYaST integration tests by using veewee,
 vagrant and pennyworth.

Features
--------

  * Building KVM images by using AutoYaST profiles.
  * Checking these KVM images with rspec tests.
  * Generating own installation ISOs with local built RPMs or the newest one from OBS.


Installation
------------

  1. Install packages 'mkdud' and 'mksusecd' from OBS.

  2. Configure `sudo` in order to run the `mksusecd`, `systemctl start
     libvirtd` and `zypper in` commands as root.

  3. Generate a ssh-key (e.g. with ssh-keygen) if you do not have one.

  4. Install [Pennyworth](https://github.com/SUSE/pennyworth#installation).

  5. Configure default network and storage for libvirt:

        $ virsh net-start default
        $ virsh net-autostart default # if you want the default network to be started automatically.
        $ virsh pool-define-as default dir - - - - /var/lib/libvirt/images
        $ virsh pool-start default
        $ virsh pool-autostart default

  6. Clone autoyast-integration-test repository and install needed GEMs

        $ git clone https://github.com/yast/autoyast-integration-test
        $ cd autoyast-integration-test
        $ bundle install

  7. If the host is running a firewall, you must permit connections from
     libvirt default network to host’s port 8888. For example, if you’re
     running SuSEfirewall2 and your libvirt default network is 192.168.122.0
     (you can check it on `/etc/libvirt/qemu/networks/default.xml`), you could
     add a custom rule allowing incoming connections from 192.168.122.0/24 to
     port 8888. After that, you must reboot your system to be sure everything
     is working properly (libvirt iptables rules, ip forwarding, etc.).

  8. Only in Tumbleweed, you must update the vagrant-libvirt plugin:

        $ NOKOGIRI_USE_SYSTEM_LIBRARIES=true vagrant plugin install vagrant-libvirt


Running
-------

For a complete list of tasks, run:

    $ rake -T

To run the testsuite, use the `test` Rake task:

    $ rake test

This runs all tests defined in spec/*.rb (e.g. spec/tftp.rb):
* Building a KVM image by using the AutoYaST configuration file (e.g. tftp.xml)
      You can watch the installation by using `virt-manager`. The image is `autoyast`.
* Starting the built image.
  You can watch it by using `virt-manager`. The image is `vagrant_autoyast_vm`.
* Running rspec tests on this machine which are defined in e.g. spec/tftp.rb.

To run only one single test use:

    $ rake test[<absolute_path_to_test_file>]

e.g. `rake test[/src/autoyast_test/spec/sles12.rb]`

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


Jenkins
-------

These AutoYaST integration tests are running on a SUSE jenkins node:

http://river.suse.de/job/autoyast-integration-test/
