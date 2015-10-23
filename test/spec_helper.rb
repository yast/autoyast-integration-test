# Copyright (c) 2013-2015 SUSE LLC
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

def run_test_script(script, expected = "AUTOYAST OK")
  shell =  File.join(File.dirname(__FILE__),"../test", script)
  expect(File.exists?(shell)).to eq(true) # Check if the script exists
  result = $vm.run(shell, sudo: true)
  expect(result[:stdout].split("\n").last).to eq(expected), proc { result[:stderr] }
end

# Copy YaST2 logs from virtual machine to a given directory
#
# It relies on AYTests::VagrantRunner#download_logs method.
# The logs will be stored in a tar.gz file. To avoid collisions,
# the compressed file's name will contain a timestamp.
#
# @param [AYTests::VagrantRunner] runner Virtual machine runner
# @param [String]                 dest   Directory where the logs will be stored
#
# @see AYTests::VagrantRunner#download_logs
def copy_logs(runner, dest = "log")
  FileUtils.mkdir(dest) unless Dir.exists?(dest)
  runner.download_logs(dest)
end

RSpec.configure do |config|
  config.before(:all) do
    AYTests.base_dir = Pathname.new(File.dirname(__FILE__)).join("..")

    # Start the previously create vagrant VM - autoyast_vm
    $vm = AYTests::VagrantRunner.new(AYTests.base_dir.join("vagrant"), AYTests.provider)
    $vm.cleanup
    $vm.start
  end

  config.after(:all) do
    examples = RSpec.world.filtered_examples.values.flatten
    # Copy the logs if some test fails.
    copy_logs($vm) if examples.any?(&:exception)
    $vm.stop
    $vm.cleanup
  end
end
