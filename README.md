# AutoYaST Integration Tests

Test framework for running AutoYaST integration tests by using Veewee and
Vagrant.

## Features

  * Building Vagrant images by using AutoYaST profiles.
  * Checking these images with RSpec tests.
  * Generating own installation ISO images with local built RPMs or the newest
    one from OBS.
  * KVM (through libvirt) and VirtualBox are supported.

## Overview

![AutoYaST testing overview](https://raw.githubusercontent.com/yast/autoyast-integration-test/master/doc/autoyast_test_workflow.jpg)

## Supported Scenarios

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

## Installation

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

## Running

This is the workflow used to run integration tests:

* Create an ISO image to test. This ISO will contain the latest YaST packages,
  although it's also possible to use any other image.
* Install the system using the generated ISO and run the tests on the resulting
  system. You can run the tests as many times as you want using the same
  installed system.

Actually, the second step can be seen as two different steps (building the
system and running the tests). But for now, we'll keep them tied.

After this brief introduction, let's go deeper into each step.

### Generating an ISO

Generating a new ISO to use in tests is as easy as typing:

    $ rake build_iso[sles12-sp1]

where `sles12-sp1` could be any of the values defined in
[config/definitions.yml](https://github.com/yast/autoyast-integration-test/blob/master/config/definitions.yml).
At this time SLE 12 (`sles12`) and SLE 12 SP1 (`sles12-sp1`) are supported.

These are the steps that will be performed by this task:

* If the original ISO is not found in the `iso` directory, it will be
  downloaded. Optionally you can just copy the ISO (retaining its _original_
  name) into the `iso` directory. You can find out the _original_ name in
  [config/definitions.yml](https://github.com/yast/autoyast-integration-test/blob/master/config/definitions.yml).
* Latest YaST packages will also be downloaded from build system (IBS/OBS). If you
  want to include your own packages, just drop them into `rpms/<definition>` directory
  (e.g. `rpms/sles12-sp1`).
* Those packages will be included in a [Driver
  Update](https://en.opensuse.org/SDB:Linuxrc#p_dud) (DUD).
* Finally, the DUD will be added to the ISO. The new ISO will be copied to
  `kiwi/iso/obs.iso`.

If you want to use another ISO, just copy it to `kiwi/iso/obs.iso` and it will
be used.

### Running the tests

Once the ISO is available, the tests are ready to run. All tests are defined in the
`test` directory. For example, to run `test/tftp.rb` test, just type:

    $ rake test[test/tftp.rb]

If you want to run all the tests in `test` directory, just type:

    $ rake test

By default, tests will run using libvirt/KVM as backend. But it's possible to select
a different provider by setting the `AYTESTS_PROVIDER` environment variable. At this
time, `libvirt` and `virtualbox` are supported:

    $ AYTESTS_PROVIDER="virtualbox" rake test[test/tftp.rb]

Now, the nitty-gritty details. For every file in `test`, these steps will be
performed:

* A new Vagrant box will be created using the ISO and the profile stored in
  `test` (e.g. `test/tftp.xml`). [Veewee](https://github.com/jedi4ever/veewee)
  will take care of this part.
* Using the generated Vagrant box, a new virtual machine will be created and
  the tests will run on that machine.
* The virtual machine will be destroyed.

### Re-running the tests

Sometimes is useful to run only a given test but skipping the installation
process, which is quite time consuming. To repeat the some test execution you
can do:

    $ bundle exec rspec <path/to/test.rb>

For example:

    $ bundle exec rspec test/tftp.rb

### Headless mode

VirtualBox can run in headless mode if needed. To do that, just set the
`AYTESTS_HEADLESS` environment variable to `true`.

    $ AYTESTS_HEADLESS="true" rake test

This setting is not relevant to libvirt/KVM which will run in *headless* mode
anyway.

### Running on local system

Sometimes could be useful to run the tests in the local system. To do that,
the `AYTESTS_LOCAL` environment variable should be set to `true`.

    $ AYTESTS_LOCAL="true" bundle exec rspec <path/to/test.rb>

For example:

    $ bundle exec rspec test/sles12.rb

Take into account that `sudo` will be used to execute testing scripts.

## Cleaning-up

Two tasks for cleaning-up stuff are available. To remove cache
(`build_iso/cache`) and [Kiwi](https://doc.opensuse.org/projects/kiwi/doc/)
state (`kiwi/import_state.yaml`) use:

    $ rake clean

If you also want to remove ISO images (downloaded and generated ones), logs and
the Vagrant box file (`kiwi/autoyast.box`), just type:

    $ rake clobber

## Caveats

* The framework can be a little bit fragile. Polishing is needed.
* Usability also needs some love.

## Solving Problems

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

### VirtualBox and KVM conflicts

You must take into account that KVM and VirtualBox can't be running at the same
time. If for example you want to switch to VirtualBox, unload `kvm` (and
related) kernel module and load `vboxdrv` and friends.

    # rmmod kvm
    # rcvboxdrv start

## Jenkins

These AutoYaST integration tests are running on a SUSE Jenkins node:

https://ci.suse.de/view/YaST/job/yast-autoyast-integration-test/
