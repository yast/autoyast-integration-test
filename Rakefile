# Copyright (c) 2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com

require "bundler/setup"
Bundler.require(:default)

require "rake/clean"

desc "Running autoyast integration tests"
task :test, [:name] do |name, args|
  base_dir = File.dirname(__FILE__)
  args[:name] ? tests = [args[:name]] : tests = Dir.glob(File.join( base_dir, "spec", "*.rb"))

  tests.each do |test_file|
    test_name = File.basename(test_file, ".rb")
    puts "---------------------------------------------------------------------------------"
    puts "********** Running test #{test_name} **********"
    puts "---------------------------------------------------------------------------------"

    puts "\n****** Creating KVM image ******\n"
    autoyast_file = File.join(base_dir, "kiwi/definitions/autoyast/autoinst.xml")
    FileUtils.cp( File.join(base_dir, "spec", test_name + ".xml"), autoyast_file)
    Dir.chdir(File.join( base_dir, "kiwi")) {
      puts "\n**** Building KVM image ****\n" 
      system "veewee kvm build autoyast --force"
      puts "\n**** Exporting KVM image into box file ****\n" 
      system "veewee kvm export autoyast --force"
    }
    FileUtils.rm(autoyast_file, :force => true)

    # Due a bug in vagrant-libvirt the images will not cleanuped correctly
    # in the /var/lib/libvirt directory. This has to be done manually
    # (including DB update)
    system "sudo virsh vol-delete vagrant_autoyast_vm.img default"

    puts "\n****** Importing vagrant box into pennyworth ******\n"
    system "pennyworth -d #{base_dir} import-base"

    if File.exist?(test_file)
      puts "\n****** Running test on created system ******\n"
      exit 1 unless system "rspec #{test_file}"
    else
      puts "\n****** Running *NO* tests on created system ******\n"
    end
  end
end

desc "Building boot image <name>- reset with name \"reset\""
task :build_iso, [:name] do |name, args|
  unless args[:name]
    puts "ERROR: name is needed"
    exit 1
  end
  FileUtils.mkdir("iso") unless File.exists?("iso")
  system "ruby #{File.join(File.dirname(__FILE__),"build_iso", args[:name]+".rb")}"
end

# Cleaning tasks
# Temporary files
CLEAN.include("build_iso/cache", "kiwi/import_state.yaml")
# Final products
CLOBBER.include("iso", "kiwi/autoyast.box", "kiwi/iso/testing.iso", "log")
