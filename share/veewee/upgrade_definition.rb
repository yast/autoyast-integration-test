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
      require "aytests/vm"
      require "aytests/#{ENV["AYTESTS_PROVIDER"]}_vm"
      vm = AYTests::VM.new(ENV["AYTESTS_IMAGE_NAME"], ENV["AYTESTS_PROVIDER"].to_sym)
      vm.restore!(ENV["AYTESTS_BACKUP_IMAGE_NAME"])
      vm.update(mac: ENV["AYTESTS_MAC_ADDRESS"], boot_order: [:cdrom, :hd])

      # Restoring obs image
      base_dir = File.dirname(__FILE__)
      testing_iso = File.join(base_dir, "iso/testing.iso")
      obs_iso = File.join(base_dir, "veewee/iso/obs.iso")
      # Taking obs iso for upgrade
      if File.file?(obs_iso) && !File.file?(testing_iso)
        FileUtils.ln(obs_iso, testing_iso)
      end
    end

  }
})
