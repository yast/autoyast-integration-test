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
    ' netsetup=dhcp',
    ' autoyast=http://%IP%:8888/autoinst.xml',
    '<Enter>'
   ],
  :ssh_login_timeout => "10000",
  :ssh_user => "vagrant",
  :ssh_password => "vagrant",
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
      require "../lib/ay_tests/web_server"
      require "pathname"
      Thread.new do
        AYTests::WebServer.new(base_dir: Pathname.pwd.join(".."), name: definition.box.name).start
      end
    end
  }
})
