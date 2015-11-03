module AYTests
  # This class will set up the system to run AutoYaST integration tests.
  # A lot of its code it's taken from Pennyworth:
  # https://github.com/SUSE/pennyworth
  class Installer
    attr_reader :config, :user, :log

    GROUPS = ["libvirt", "qemu", "kvm", "vboxusers"]
    POLKIT_RULES_PATH = "/etc/polkit-1/rules.d/99-libvirt.rules"
    POLKIT_RULES_SAMPLE = File.join(File.dirname(__FILE__), "..", "..", "files", "99-libvirt.rules")

    # Constructor
    #
    # @param [Hash]     config Configuration (check +config/setup.yml+).
    # @param [String]   user   Username to give permissions to.
    # @param [Logger]   log    Logger object.
    def initialize(config, user, log = nil)
      @config = config
      @user = user
      @log = Logger.new(STDOUT)
    end

    # Run the installation/configuration process
    #
    # * Install packages from repositories (as defined in +config/setup.yml+).
    # * Install additional packages (also defined in +config/setup.yml+).
    # * Reload udev rules.
    # * Install libvirt Vagrant plugin.
    # * Add user to virtualization groups.
    # * Disable PolicyKit authentication for libvirt.
    # * Allow access to libvirt for regular users.
    # * Allow user access to qemu_kvm.
    # * Enable services and configure libvirt network and storage.
    def run
      # Install software
      log.info "Installing lsb-release in order to determine system version"
      zypper_install("lsb-release") # Needed to determine system version
      install_packages_from_repos
      install_additional_packages
      reload_udev_rules
      install_vagrant_plugin

      # Set up permissions
      add_user_to_groups
      disable_libvirt_policykit_auth
      allow_libvirt_access
      allow_qemu_kvm_access
      allow_arp_access

      # Configure libvirt
      activate_libvirt
      configure_libvirt
    end

    # Install packages from repositories
    #
    # Packages are listed in +config/setup.yml+. It will install those
    # packages listed:
    #
    # * in the +common+ key,
    # * in the key which correspond to the running system (13.1, 13.2, etc.).
    #
    # Adapted from Pennyworth.
    def install_packages_from_repos
      packages = config["packages"]["common"]

      if config["packages"][base_system]
        packages += config["packages"][base_system]
      end

      log.info "Installing packages from repositories"
      zypper_install(packages)
    end

    # Install additional repositories
    #
    # Packages are listed in +config/setup.yml+. It will install those
    # packages listed in the +remote+ key.
    #
    # Adapted from Pennyworth.
    def install_additional_packages
      config["packages"]["remote"].each do |name, url|
        begin
          Cheetah.run "rpm", "-qi", name
        rescue
          log.info "Installing additional package #{name} from #{url}"
          zypper_install(url)
        end
      end
    end

    # Reload udev rules
    #
    # The kvm package does come with a udev rule file to adjust ownership of
    # /dev/kvm. However, the installation of the package does not trigger a
    # reload of the udev rules. In order for /dev/kvm to have the right
    # ownership we need to reload the udev rules ourself.
    #
    # Adapted from Pennyworth.
    def reload_udev_rules
      log.info "Reloading udev rules"
      Cheetah.run "sudo", "/sbin/udevadm", "control", "--reload-rules"
      Cheetah.run "sudo", "/sbin/udevadm", "trigger"
    end

    # Install libvirt Vagrant plugin
    #
    # Installation is skipped if plugin is installed for the current user.
    #
    # Adapted from Pennyworth.
    def install_vagrant_plugin
      return if vagrant_libvirt_installed?
      log.info "Installing libvirt plugin for Vagrant"
      Cheetah.run "vagrant", "plugin", "install", "vagrant-libvirt"
    end

    # Add user to virtualization groups
    #
    # Groups are defined through the constant GROUPS.
    #
    # Adapted from Pennyworth.
    def add_user_to_groups
      log.info "Adding user '#{@user}' to groups: #{GROUPS.join(" ")}"

      GROUPS.each do |group|
        Cheetah.run "sudo", "/usr/sbin/usermod", "-a", "-G", group, @user
      end
    end

    # Disable PolicyKit authentication for libvirt
    #
    # Without this, PolicyKit would pop-up a dialog asking for root password
    # every time you do something with libvirt as a normal user. This would
    # break the setup workflow and fail on headless machines.
    #
    # Adapted from Pennyworth.
    def disable_libvirt_policykit_auth
      log.info "Disabling PolicyKit authentication for libvirt"
      Cheetah.run "sudo", "cp", POLKIT_RULES_SAMPLE, POLKIT_RULES_PATH
    end

    # Enable access to libvirt for regular users
    #
    # Unix sockets will be used.
    #
    # Adapted from Pennyworth.
    def allow_libvirt_access
      log.info "Allowing libvirt access for normal users"

      adapt_config_file "/etc/libvirt/libvirtd.conf",
        :unix_sock_group    => "libvirt",
        :unix_sock_ro_perms => "0777",
        :unix_sock_rw_perms => "0770",
        :auth_unix_rw       => "none",
        # By default, libvirt logs to syslog. We'd like to have the logs
        # separated.
        :log_outputs        => "1:file:/var/log/libvirt/libvirt.log"
    end

    # Allow QEMU/KVM access to main user
    #
    # Adapted from Pennyworth.
    def allow_qemu_kvm_access
      log.info "Allowing qemu-kvm access for user #{user}"

      adapt_config_file "/etc/libvirt/qemu.conf",
        :user  => user,
        :group => "qemu"
    end

    # Make arp available to Veewee
    #
    # Veewee will fail because arp can't be found when running as a normal
    # user.
    #
    # Adapted from Pennyworth.
    def allow_arp_access
      log.info "Making arp command available for normal users..."
      Cheetah.run "sudo", "ln", "-sf", "/sbin/arp", "/usr/bin"
    end

    # Enable and start libvirtd
    #
    # If libvirtd is running yet, it will try to reload/restart
    # the service.
    #
    # Adapted from Pennyworth.
    def activate_libvirt
      Cheetah.run %w(sudo systemctl enable libvirtd)
      Cheetah.run %w(sudo systemctl reload-or-restart libvirtd)
    end

    # Configure libvirt network and storage
    #
    # +default+ network will be enabled and marked for autostart.
    # Moreover, a +default+ storage pool will be defined.
    def configure_libvirt
      log.info "Setting up libvirt network and storage"
      Cheetah.run %w(sudo virsh net-autostart default)
      unless libvirt_pool_default_defined?
        Cheetah.run %w(sudo virsh pool-define-as default dir - - - - /var/lib/libvirt/images)
      end
      Cheetah.run %w(sudo virsh pool-autostart default)
      Cheetah.run %w(sudo systemctl reload-or-restart libvirtd)
    end

    private

    # Install a package using Zypper
    #
    # Adapted from Pennyworth.
    def zypper_install(packages)
      parts = [
        "sudo",
        "zypper",
        "--non-interactive",
        "install",
        "--auto-agree-with-licenses",
        "--name"
      ]
      candidates = Array(packages)
      to_install = candidates.select do |name|
        begin
          Cheetah.run "rpm", "-qi", name
          false
        rescue
          true
        end
      end
      if to_install.empty?
        log.info "All needed packages were already installed (#{candidates.join(" ")})"
      else
        log.info "Installing: #{to_install.join(" ")}"
        Cheetah.run(parts + to_install)
      end
    end

    # Determine the system version through lsb_release
    #
    # Adapted from Pennyworth.
    def base_system
      Cheetah.run(["lsb_release", "--release"], :stdout => :capture).split[1]
    end

    # Check whether libvirt Vagrant plugin is installed or not
    #
    # Adapted from Pennyworth.
    def vagrant_libvirt_installed?
      Cheetah.run(%w(vagrant plugin list), %w(grep vagrant-libvirt))
      true
    rescue
      false
    end

    # Check whether libvirt default storage pool exists or not
    def libvirt_pool_default_defined?
      Cheetah.run %w(sudo virsh pool-info default)
      true
    rescue
      false
    end

    # Adapt configuration files
    #
    # Set file settings described by +adaptations+ hash.
    #
    # @param [String] file        Path to the file to adapt.
    # @param [Hash]   adaptations Define keys and values to be set on the file.
    # Adapted from Pennyworth.
    def adapt_config_file(file, adaptations)
      # Create a backup.
      Cheetah.run "sudo", "cp", file, "#{file}.backup"

      # Create a temporary copy with permissions that allow us to modify it.
      temp_file = "/tmp/#{File.basename(file)}.tmp"
      Cheetah.run "sudo", "cp", file, temp_file
      Cheetah.run "sudo", "chmod", "a+rw", temp_file

      # Do the adaptations.
      content = File.read(temp_file)
      adaptations.each_pair do |key, value|
        regexp_uncommented = /^(\s*)#{key}(\s*)=(\s*).*$/
        regexp_commented   = /^(\s*)\#?#{key}(\s*)=(\s*).*$/
        replacement = "\\1#{key}\\2=\\3#{value.inspect}"

        # We need to be careful here because sometimes there are both commented
        # and uncommented lines in the file. In that case, we want to modify the
        # first uncommented line and keep the commented ones intact. On the other
        # hand, if there are just commented lines, we want to uncomment and modify
        # the first one.
        if content =~ regexp_uncommented
          content.sub!(regexp_uncommented, replacement)
        elsif content =~ regexp_commented
          content.sub!(regexp_commented, replacement)
        else
          raise "#{file} No #{key.inspect} option to adapt."
        end
      end
      File.write(temp_file, content)

      # Replace the original file with the temporary copy, keep its permissions
      # intact.
      permissions = Cheetah.run(
        "sudo",
        "stat",
        "--printf",
        "%a",
        file,
        :stdout => :capture
      )
      Cheetah.run "sudo", "mv", temp_file, file
      Cheetah.run "sudo", "chmod", permissions, file
    end
  end
end
