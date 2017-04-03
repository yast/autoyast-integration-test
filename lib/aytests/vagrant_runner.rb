require "fileutils"

module AYTests
  class VagrantRunner
    VM_NAME = "autoyast_vm".freeze

    attr_reader :vagrantfile, :dir, :ssh_config

    # Constructor
    #
    # @param [Pathname] dir      Vagrantfile directory
    # @param [Symbol]   provider Vagrant provider to use (:libvirt or :virtualbox)
    def initialize(vagrantfile, dir, provider = :libvirt)
      @vagrantfile = vagrantfile
      @dir = dir
      @provider = provider
      @ssh_config = @dir.join("config.ssh")
    end

    # Start the virtual machine
    #
    # @return [Boolean] true if the system started successfully; otherwise
    #   false is returned
    def start
      setup
      Dir.chdir(dir) do
        system "vagrant up #{VM_NAME} --provider #{@provider}"
        system "vagrant ssh-config > #{@ssh_config}"
        system "vagrant ssh -c 'true'" # Wait until SSH is ready
      end
    end

    # Stop the virtual machine
    #
    # @return [Boolean] true if the system stopped successfully; otherwise
    #   false is returned
    def stop
      return false unless dir.directory?
      Dir.chdir(dir) do
        system "vagrant halt"
      end
    end

    # Run a script in the Vagrant machine
    #
    # Copy the script to the Vagrant system and execute it.
    #
    # @param [String|Pathname]  script Path to the script in the local system
    # @param [Boolean]          sudo   Determine if the command should be executed
    #   using +sudo+
    def run(script, sudo: false)
      with_conn do |conn|
        target = "/tmp/#{File.basename(script)}"
        conn.scp_put VM_NAME, script.to_s, target, config: @ssh_config
        conn.ssh VM_NAME, "/usr/bin/chmod +x #{target}"
        command = "/usr/bin/env #{target}"
        command.prepend("sudo ") if sudo
        result = conn.ssh VM_NAME, command
        conn.ssh VM_NAME, "/usr/bin/rm #{target}"
        result
      end
    end

    # Clean-up the machine and the ssh configuration
    def cleanup
      return false unless dir.directory?
      Dir.chdir(dir) do
        FileUtils.rm_rf(@ssh_config)
        system "vagrant destroy --force"
      end
    end

  private

    # Open a SSH connection a execute a block of code in that context
    def with_conn
      conn = Net::SSH::Simple.new(config: @ssh_config)
      result = yield conn
      conn.close
      result
    end

    # Set up the Vagrant environment
    def setup
      FileUtils.mkdir_p(dir)
      FileUtils.cp(vagrantfile, dir)
    end
  end
end
