require "logger"
require "ay_tests/media_builder"
require "ay_tests/image_builder.rb"
require "ay_tests/iso_repo"

module AYTests
  def self.base_dir=(path)
    @base_dir = Pathname.new(path)
  end

  def self.base_dir
    @base_dir
  end

  def self.obs_iso_path
    base_dir.join("kiwi", "iso", "obs.iso")
  end
end
