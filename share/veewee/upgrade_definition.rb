require "aytests/veewee_hooks"

hooks = AYTests::VeeweeHooks.new(
  definition:        veewee_definition,
  provider:          ENV["AYTESTS_PROVIDER"].to_sym,
  files_dir:         ENV["AYTESTS_FILES_DIR"].to_s,
  sources_dir:       ENV["AYTESTS_SOURCES_DIR"].to_s,
  results_dir:       ENV["AYTESTS_RESULTS_DIR"].to_s,
  ip_address:        ENV["AYTESTS_IP_ADDRESS"],
  mac_address:       ENV["AYTESTS_MAC_ADDRESS"],
  webserver_port:    ENV["AYTESTS_WEBSERVER_PORT"].to_i,
  backup_image_name: ENV["AYTESTS_BACKUP_IMAGE_NAME"]
)

Veewee::Definition.declare(
  cpu_count:            "2",
  memory_size:          "1024",
  disk_size:            "25600",
  disk_format:          "VDI",
  hostiocache:          "off",
  os_type_id:           "OpenSUSE_64",
  iso_file:             "testing.iso",
  iso_src:              "__iso_source_path__",
  iso_md5:              "",
  iso_download_timeout: "1000",
  boot_wait:            "10",
  boot_cmd_sequence:    [
    "<Esc><Enter>",
    "     ", # Workaround to avoid timing problems with VirtualBox
    "linux",
    " instmode=dvd",
    " textmode=1",
    " insecure=1",
    " autoupgrade=1",
    " netsetup=dhcp",
    " SetHostname=0",
    # Disable predictable network interface names until we have a better
    # solution (bsc#1053034)
    " biosdevname=0",
    " net.ifnames=0",
    " #{ENV["AYTESTS_LINUXRC"]}",
    " netdevice= ", # Only needed for SLES11 installation. So removing this entry again.
    "<Enter>"
  ],
  ssh_login_timeout:    "3600",
  ssh_user:             "vagrant",
  ssh_password:         "nots3cr3t",
  ssh_key:              "",
  ssh_host_port:        "7222",
  ssh_guest_port:       "22",
  sudo_cmd:             "echo '%p'|sudo -S sh '%f'",
  shutdown_cmd:         "shutdown -P now",
  postinstall_files:    [],
  hooks:                {
    before_create:     proc { hooks.before_create },
    after_create:      proc { hooks.after_create_on_upgrade },
    after_postinstall: proc { hooks.after_postinstall },
    after_up:          proc { hooks.after_up }
  }
)
