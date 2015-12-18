Veewee::Definition.declare({
  :cpu_count => '2',
  :memory_size=> '1024',
  :disk_size => '20280',
  :disk_format => 'VDI',
  :hostiocache => 'off',
  :os_type_id => 'OpenSUSE_64',
  :iso_file => "testing.iso",
  :iso_src => "__iso_source_path__",
  :iso_md5 => "",
  :iso_download_timeout => "1000",
  :boot_wait => "10",
  :boot_cmd_sequence => [
    '<Esc><Enter>',
    '     ', # Workaround to avoid timing problems with VirtualBox
    'linux',
    ' netdevice=eth0',
    ' instmode=dvd',
    ' textmode=1',
    ' insecure=1',
    ' autoupgrade=1',
    ' netsetup=dhcp',
    " autoyast=http://%IP%:#{ENV["AYTESTS_WEBSERVER_PORT"]}/autoinst.xml",
    " #{ENV["AYTESTS_LINUXRC"]}",
    '<Enter>'
   ],
  :ssh_login_timeout => "10000",
  :ssh_user => "vagrant",
  :ssh_password => "nots3cr3t",
  :ssh_key => "",
  :ssh_host_port => "7222",
  :ssh_guest_port => "22",
  :sudo_cmd => "echo '%p'|sudo -S sh '%f'",
  :shutdown_cmd => "shutdown -P now",
  :postinstall_files => [ "postinstall.sh" ],
  :postinstall_timeout => "10000",
  :hooks => {
    # Before starting the build we spawn a webrick webserver which serves the
    # autoyast profile to the installer. veewee's built in webserver solution
    # doesn't work reliably with autoyast due to some timing issues.
    :before_create => Proc.new do
      require "aytests/web_server"
      require "pathname"
      Thread.new do
        AYTests::WebServer.new(
          veewee_dir: Pathname.pwd.join("definitions", "autoyast"),
          files_dir: ENV["AYTESTS_FILES_DIR"],
          name: definition.box.name).start
      end
    end,
    :after_create => Proc.new do
      # Restoring old autoyast image which has to be updated.
      # FIXME: it's a little bit tricky and it deserves some refactoring/cleanup.
      if ENV["AYTESTS_PROVIDER"] == "virtualbox"
        puts "restoring the saved autoyast virtual machine"
        vm_config = `VBoxManage showvminfo autoyast | grep "Config file" | cut -f2 -d:`.strip
        vm_dir = File.dirname(vm_config)
        system "VBoxManage unregistervm autoyast --delete"
        FileUtils.mv vm_dir.sub("autoyast", "autoyast.sav"), vm_dir
        system "VBoxManage registervm \"#{vm_config}\""
        puts "changing boot order (DVD first)"
        system "VBoxManage modifyvm autoyast --boot1 dvd --boot2 disk --boot3 none --boot4 none"
      else
        mac = `xmllint --xpath  \"string(//domain/devices/interface/mac/@address)\" autoyast_description.xml`
        system "sudo virsh undefine autoyast --remove-all-storage"
        puts "generating autoyast image with mac address: #{mac}"
        system "sudo virt-clone -o autoyast_sav -n autoyast --file /var/lib/libvirt/images/autoyast.qcow2 --mac #{mac}"
        system "sudo virsh undefine autoyast_sav --remove-all-storage"
        FileUtils.rm("autoyast_description.xml", force: true)
      end

      # Restoring obs image
      base_dir = File.dirname(__FILE__)
      testing_iso = File.join(base_dir, "iso/testing.iso")
      obs_iso = File.join(base_dir, "iso/obs.iso")
      # Taking obs iso for upgrade
      if File.file?(obs_iso) && !File.file?(testing_iso)
        FileUtils.ln(obs_iso, testing_iso)
      end
    end

  }
})
