module AYTests
  class VagrantRunner
    VM_NAME = "autoyast_vm"

    attr_reader :dir, :ssh_config

    # Constructor
    #
    # @param [Pathname] dir      Vagrantfile directory
    # @param [Symbol]   provider Vagrant provider to use (:libvirt or :virtualbox)
    def initialize(dir, driver = :libvirt)
      @dir = dir
      @driver = driver
      @ssh_config = @dir.join("config.ssh")
    end

    # Start the virtual machine
    #
    # @return [Boolean] true if the system started successfully; otherwise
    #   false is returned
    def start
      Dir.chdir(dir) do
        system "vagrant up #{VM_NAME} --provider #{@driver}"
        system "vagrant ssh-config > #{@ssh_config}"
        system "vagrant ssh -c 'true'" # Wait until SSH is ready
      end
    end

    # Stop the virtual machine
    #
    # @return [Boolean] true if the system stopped successfully; otherwise
    #   false is returned
    def stop
      Dir.chdir(dir) do
        system "vagrant halt"
      end
    end

    # Run a script in the Vagrant machine
    #
    # Copy the script to the Vagrant system and execute it.
    #
    # @param [String]  script Path to the script in the local system
    # @param [Boolean] sudo   Determine if the command should be executed
    #   using +sudo+
    def run(script, sudo: false)
      with_conn do |conn|
        target = "/tmp/#{File.basename(script)}"
        conn.scp_put VM_NAME, script, target, config: @ssh_config
        conn.ssh VM_NAME, "/usr/bin/chmod +x #{target}"
        command = "/usr/bin/env #{target}"
        command.prepend("sudo ") if sudo
        result = conn.ssh VM_NAME, command
        conn.ssh VM_NAME, "/usr/bin/rm #{target}"
        result
      end
    end

    # Download YaST logs to a given directory
    #
    # @param [String,Pathname] dest Directory to copy logs to
    # @return [Boolean] +true+ if the log was saved; +false+ otherwise
    def download_logs(dest)
      with_conn do |conn|
        tar_path = "/tmp/YaST2-#{Time.now.strftime('%Y%m%d%H%M%S')}.tar.gz"
        conn.ssh VM_NAME, "sudo save_y2logs #{tar_path}"
        result = conn.scp_get VM_NAME, tar_path, dest.to_s
        result[:success]
      end
    end


    # Clean-up the machine and the ssh configuration
    def cleanup
      Dir.chdir(dir) do
        system "vagrant destroy --force"
        FileUtils.rm_rf(@ssh_config)
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
  end
end
