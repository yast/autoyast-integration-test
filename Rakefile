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

    testing_iso = File.join(base_dir, "kiwi/iso/testing.iso")
    obs_iso = File.join(base_dir, "kiwi/iso/obs.iso")
    autoyast_file = File.join(base_dir, "kiwi/definitions/autoyast/autoinst.xml")
    dest_definition = File.join(base_dir, "kiwi/definitions/autoyast/definition.rb")
    default_iso = "http://dist.suse.de/install/SLE-12-Server-GM/SLE-12-Server-DVD-x86_64-GM-DVD1.iso"

    FileUtils.rm(testing_iso, :force => true)

    # Set used iso
    unless test_name.start_with?("upgrade_")
      # New installation workflow. So we take the built OBS iso
      FileUtils.ln(obs_iso, testing_iso) if File.file?(obs_iso)
    end
    # Set download iso path. This path will be taken for download, if the iso has not already been
    # downloaded.
    src_definition = File.join(base_dir, "kiwi/definitions/autoyast/install_definition.rb")
    FileUtils.cp(src_definition, dest_definition)
    iso_path_file = File.join(base_dir, "spec", test_name + ".install_iso")
    if File.file?(iso_path_file)
      data = IO.binread(iso_path_file).chomp
    else
      data = default_iso
    end
    system "sed -i.bak s,__iso_source_path__,#{data},g #{dest_definition}"

    # Set autoinst.xml
    autoinst = File.join(base_dir, "spec", test_name + ".xml")
    autoinst = File.join(base_dir, "spec", test_name + ".install_xml") unless File.file?(autoinst)
    FileUtils.cp( autoinst, autoyast_file)

    puts "\n****** Creating KVM image ******\n"
    Dir.chdir(File.join( base_dir, "kiwi")) do
      puts "\n**** Building KVM image ****\n" 
      system "veewee kvm build autoyast --force --auto"
    end

    if test_name.start_with?("upgrade_")
      # upgrade workflow
      # Take the generated image and run a autoyast upgrade workflow

      # Set used iso
      FileUtils.rm(testing_iso, :force => true)
      FileUtils.ln(obs_iso, testing_iso) if File.file?(obs_iso) #Taking obs iso for upgrade

      # Change boot order to CD on the top
      system "sudo virsh destroy autoyast"
      system "sudo virsh dumpxml autoyast >autoyast_description.xml"
      system "sudo sed -i.bak s/dev=\\'cdrom\\'/dev=\\'cdrom_save\\'/g autoyast_description.xml"
      system "sudo sed -i.bak s/dev=\\'hd\\'/dev=\\'cdrom\\'/g autoyast_description.xml"
      system "sudo sed -i.bak s/dev=\\'cdrom_save\\'/dev=\\'hd\\'/g autoyast_description.xml"
      system "sudo virsh define autoyast_description.xml"

      # Save generated autoyast image which has to be updated. Because it will be overwritten by
      # veewee in the next call. The restore process will be done in the after_create section of veewee defintion.
      mac = `sudo xmllint --xpath  \"string(//domain/devices/interface/mac/@address)\" autoyast_description.xml`
      system "sudo virt-clone -o autoyast -n autoyast_sav --file /var/lib/libvirt/images/autoyast_sav.qcow2 --mac #{mac}"
      system "sudo rm autoyast_description.*"

      # Take update definition for veewee
      src_definition = File.join(base_dir, "kiwi/definitions/autoyast/upgrade_definition.rb")
      FileUtils.cp(src_definition, dest_definition)


      # Set download iso path. This path will be taken for download, if the iso has not already been
      # downloaded.
      iso_path_file = File.join(base_dir, "spec", test_name + ".upgrade_iso")
      if File.file?(iso_path_file)
        data = IO.binread(iso_path_file).chomp
      else
        data = default_iso
      end
      system "sed -i.bak s,__iso_source_path__,#{data},g #{dest_definition}"

      # Set autoinst.xml
      autoinst = File.join(base_dir, "spec", test_name + ".upgrade_xml")
      unless File.file?(autoinst)
        puts "ERROR: #{autoinst} not found"
        exit 1
      end
      FileUtils.cp( autoinst, autoyast_file)

      Dir.chdir(File.join( base_dir, "kiwi")) do
        puts "\n**** Updating KVM image ****\n"
        system "veewee kvm build autoyast --force --auto"
      end
    end

    Dir.chdir(File.join( base_dir, "kiwi")) do
      puts "\n**** Exporting KVM image into box file ****\n" 
      system "veewee kvm export autoyast --force"
    end
    FileUtils.rm(autoyast_file, :force => true)
    FileUtils.rm(dest_definition, :force => true)

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
