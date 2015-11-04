AutoYaST Integration Tests
===========================

Test framework for running AutoYaST integration tests by using Veewee and
Vagrant.

Features
--------

  * Building Vagrant images by using AutoYaST profiles.
  * Checking these images with RSpec tests.
  * Generating own installation ISO images with local built RPMs or the newest
    one from OBS.
  * KVM (through libvirt) and VirtualBox are supported.

Supported Scenarios
-------------------

These integration tests need to start virtual machines for their operation.
If you want to use KVM, support for hardware virtualization is vitally important.
Check it on your host system:

    $ grep --only-matching '\(svm\|vmx\)' /proc/cpuinfo

Alternatively, you can just use VirtualBox (no hardware virtualization support
is needed).

If you prefer, you can install the framework in a KVM machine. For that
scenario to work you must enable _nested virtualization_. For example, if
you're using libvirt, you can achieve that setting `cpu mode` to `host-model`
or `host-passthrough`. You can find more information in the [official
documentation](https://libvirt.org/formatdomain.html#elementsCPU).

Installation
------------

  1. Install packages [mkdud](https://software.opensuse.org/package/mkdud?search_term=mkdud)
     and [mksusecd](https://software.opensuse.org/package/mksusecd?search_term=mksusecd)
     from OBS.

        $ sudo zypper install ./mkdud-*.rpm ./mksusecd-*.rpm

  2. Unless you run tests as 'root', configure `sudo` in order to run the `mksusecd`,
     `systemctl start libvirtd` and `zypper in` commands as root.

     This will grant access to execute every command for user <username> as root without
     asking for password (unsecure):

        echo '<username> ALL=NOPASSWD: ALL' >> /etc/sudoers

  3. Clone autoyast-integration-test repository and install needed gems.
     The use of the `--path` option is recommended to avoid polluting your
     system:

        $ git clone https://github.com/yast/autoyast-integration-test
        $ cd autoyast-integration-test
        $ sudo zypper install rubygem-bundler
        $ bundle config --local build.nokogiri --use-system-libraries
        $ bundle install --without test --path vendor/bundle

  4. The task `setup` will do a lot of work for you. After that, you need to install
     the missing gems:

        $ rake setup
        $ bundle install --without ''

  5. If the host is running a firewall, you must permit connections from
     libvirt default network to host’s port 8888. For example, if you’re
     running SuSEfirewall2 and your libvirt default network is 192.168.122.0
     (you can check it on `/etc/libvirt/qemu/networks/default.xml`), you could
     add a custom rule to /etc/sysconfig/SuSEfirewall2 allowing incoming
     connections from 192.168.122.0/24 to TCP port 8888, e.g.:

        FW_SERVICES_ACCEPT_EXT="192.168.122.0/24,tcp,8888"

     After that, you must reboot your system to be sure everything works
     properly (libvirt iptables rules, ip forwarding, etc.).

Running
-------

For a complete list of tasks, run:

    $ rake -T

To run the testsuite, use the `test` Rake task:

    $ rake test

This runs all tests defined in `test` directory (e.g. `test/tftp.rb`):
* Building a KVM image by using the AutoYaST configuration file (e.g. `tftp.xml`)
  You can watch the installation by using `virt-manager`. The image is `autoyast`.
* Starting the built image.
  You can watch it by using `virt-manager`. The image is `vagrant_autoyast_vm`.
* Running RSpec tests on this machine which are defined in e.g. `test/tftp.rb`.

To run only one single test use:

    $ rake test[<path_to_test_file>]

e.g. `rake test[test/sles12.rb]`

or you can also run any single script directly

    $ bundle exec rspec [<path_to_test_file>]

To generate a new installation image based on SLES12 SP1 call:

    $ rake build_iso[sles12-sp1]

* Fetching all RPMs (defined in build_iso/sles12-sp1.obs_packages) from OBS.
* Fetching all local RPMs (drop packages in `rpms/VERSION` directory).
* Fetching official SLES12 SP1 ISO.
* Generating a new SLES12 SP1 ISO with this new RPM packages.
* Copying new SLES12 SP1 ISO into test environment (directory kiwi/iso).

This new ISO image will be used for running tests in the future.

To use the official SLES12 SP1 ISO (default setting) for tests just call:

    $ rake build_iso[default]

Selecting a provider
--------------------

You can select a provider for Vagrant using a environment variable called
`AYTESTS_PROVIDER`. Possible values are `libvirt` (default) and `virtualbox`.

    $ AYTESTS_PROVIDER="virtualbox" rake test[test/sles12.rb]

You must take into account that KVM and VirtualBox can't be running at the same
time. If for example you want to switch to VirtualBox, unload `kvm` kernel
module and load `vboxdrv` and friends.

    # rmmod kvm
    # rcvboxdrv start

Caveats
-------

* The framework can be a little bit fragile. Polishing is needed.

Solving Problems
----------------

### Connection to libvirt

If you are experiencing *There was a problem opening a connection to libvirt:
libvirt is not a recognized compute provider* error, you might need to
downgrade gems 'fog' and 'fog' core to version 1.30 to 1.29

    $ gem list fog
    $ gem install fog --version 1.29
    $ gem uninstall fog --version 1.30
    $ gem install fog-core --version 1.29
    $ gem uninstall fog-core --version 1.30

### libvirt 'default' network does not start

If you're running AutoYaST integration tests in a virtual machine (as mentioned
in the _Supported Scenarios_ section) you should make sure that you're using different
IP ranges. For example, if you are using `192.168.122.0/24` in the host machine, you should
use another one (e.g. `192.168.123.0/24`) in the guest. The following commands will be
helpful:

    $ sudo virsh net-dumpxml default
    $ sudo virsh net-edit default

Finally, don't use `192.168.121.0/24` as it will be used by libvirt Vagrant plugin.

Jenkins
-------

These AutoYaST integration tests are running on a SUSE Jenkins node:

https://ci.suse.de/view/YaST/job/yast-autoyast-integration-test/
