require "logger"
require "ay_tests/helpers"
require "ay_tests/media_builder"
require "ay_tests/image_builder"
require "ay_tests/iso_repo"

module AYTests
  # Set the base directory for AYTests
  #
  # @param [Pathname, String] path Directory to use as base.
  # @return [Pathname, String] Base directory (the provided argument).
  def self.base_dir=(path)
    @base_dir = Pathname.new(path)
  end

  # Return the base directory for AYTests
  #
  # @param [Pathname] Directory used as base.
  def self.base_dir
    @base_dir
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
    base_dir.join("kiwi", "iso", "obs.iso")
  end

  # Return the path to the integration tests
  #
  # @return [Pathname] Path to the integration tests
  def self.tests_path
    base_dir.join("test")
  end
end
