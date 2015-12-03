require "logger"
require "net/ssh/simple"
require "cheetah"
require "aytests/helpers"
require "aytests/media_builder"
require "aytests/image_builder"
require "aytests/iso_repo"
require "aytests/vagrant_runner"
require "aytests/test_runner"

module AYTests
  def self.init(work_dir)
    work_dir_path = Pathname.new(work_dir)
    self.work_dir = work_dir_path.absolute? ? work_dir_path : work_dir_path.realdirpath
    FileUtils.mkdir_p(work_dir) unless self.work_dir.exist?
  end

  # Return the base directory for AYTests
  #
  # @return [Pathname] Directory used as base.
  def self.base_dir
    @base_dir ||= Pathname.new(File.dirname(__FILE__)).join("..")
  end

  # Set the work directory for AYTests
  #
  # @param [Pathname, String] path Directory to use as workspace.
  # @return [Pathname, String] Work directory (the provided argument).
  def self.work_dir=(path)
    @work_dir = Pathname.new(path)
  end

  # Return the work directory for AYTests
  #
  # @return [Pathname] Directory used as workspace.
  def self.work_dir
    @work_dir || Pathname.pwd.join("aytests")
  end

  # Set the logger for AYTests messages
  #
  # @param [Logger] logger Logger to be used.
  # @return [Logger] Logger (the provided argument).
  def self.logger=(logger)
    @logger = logger
  end

  # Return the logger for AYTests messages
  #
  # If no logger was set using AYTests.logger= method, a new one
  # will be constructed using STDOUT.
  #
  # @return [Logger] Logger object.
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  # Return the path to the built ISO image
  #
  # @return [Pathname] Path to the image.
  def self.obs_iso_path
    work_dir.join("veewee", "iso", "obs.iso")
  end

  # Return the path to the integration tests
  #
  # @return [Pathname] Path to the integration tests
  def self.tests_path
    base_dir.join("test")
  end

  # Return the provider to be used by Vagrant
  #
  # If it was not set by using AYTests.provider= method, it will be
  # taken from +AYTESTS_PROVIDER+ environment variable. Possible values
  # are +libvirt+ and +virtualbox+.
  #
  # @return [Symbol] Provider to be used by Vagrant (+libvirt+ or +virtualbox+)
  def self.provider
    @provider ||= (ENV["AYTESTS_PROVIDER"] || "libvirt").to_sym
  end

  # Set the Vagrant provider
  #
  # @param [Symbol] provider Provider to be used by Vagrant
  #    (:libvirt or :virtualbox)
  def self.provider=(provider)
    @provider = provider
  end
end
