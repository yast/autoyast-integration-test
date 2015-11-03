# Copyright (c) 2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com

# Default environment variables
ENV["VAGRANT_LOG"] ||= "warn"         # Set Vagrant log level to 'warn'
ENV["AYTESTS_PROVIDER"] ||= "libvirt" # Set libvirt as the default provider

require "bundler/setup"
Bundler.require(:default)

require "rake/clean"
require "yaml"

def iso_repo
  if `hostname --domain`.chomp == "suse.cz"
    "http://fallback.suse.cz"
  else
    "http://dist.suse.de"
  end
end

base_dir = Pathname.new(File.dirname(__FILE__))
Dir[base_dir.join("lib", "tasks", "*")].each { |t| require_relative t }

task :bootstrap do
  $LOAD_PATH.unshift File.join(File.dirname(__FILE__), "lib")
  require "ay_tests"
  AYTests.base_dir = base_dir
  AYTests::IsoRepo.init(AYTests.base_dir.join("iso"))
end

desc "Running autoyast integration tests"
task :test, [:name] => :bootstrap do |name, args|
  tests = Array(args[:name] || Dir.glob(AYTests.tests_path.join("*.rb")))

  tests.sort.each do |test_file|
    test_name = File.basename(test_file, ".rb")
    puts "********** Running test #{test_name} **********"

    autoinst = AYTests.tests_path.join("#{test_name}.xml")
    autoinst = AYTests.tests_path.join("#{test_name}.install_xml") unless autoinst.file?

    # Set download iso path. This path will be taken for download, if the iso has not already been
    # downloaded.
    iso_path_file = AYTests.tests_path.join("#{test_name}.install_iso")
    iso_url = File.file?(iso_path_file) ? IO.binread(iso_path_file).chomp : AYTests.obs_iso_path

    builder = AYTests::ImageBuilder.new(provider: AYTests.provider)
    builder.install(autoinst, iso_url)

    if test_name.start_with?("upgrade_")
      # Set download iso path. This path will be taken for download, if the iso has not already been
      # downloaded.
      iso_path_file = AYTests.tests_path.join("#{test_name}.upgrade_iso")
      iso_url = File.file?(iso_path_file) ? IO.binread(iso_path_file).chomp : AYTests.obs_iso_path

      # Set autoinst.xml
      autoinst = AYTests.tests_path.join("#{test_name}.upgrade_xml")
      builder.upgrade(autoinst, iso_url)
    end

    builder.import
    builder.cleanup

    if File.exist?(test_file)
      puts "\n****** Running test on created system ******\n"
      exit 1 unless system "rspec #{test_file}"
    else
      puts "\n****** Running *NO* tests on created system ******\n"
    end
  end
end

desc "Building boot image <name>- reset with name \"reset\""
task :build_iso, [:name] => :bootstrap do |name, args|
  unless args[:name]
    puts "ERROR: name is needed"
    exit 1
  end

  base_dir = Pathname.new(File.dirname(__FILE__))
  config = YAML.load_file(base_dir.join("config", "definitions.yml")).fetch(args[:name].to_sym)
  builder = AYTests::MediaBuilder.new(config.merge(base_dir: base_dir, version: args[:name]))
  builder.build
end

# Cleaning tasks
# Temporary files
CLEAN.include("build_iso/cache", "kiwi/import_state.yaml")
# Final products
CLOBBER.include("iso", "kiwi/autoyast.box", "kiwi/iso/testing.iso", "log")
