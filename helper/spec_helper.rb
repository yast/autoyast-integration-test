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

# Require the spec.rb from pennyworth. Adjust the path to where you checked out pennyworth from git.
require "pennyworth/spec"
require "pennyworth/ssh_keys_importer"

def run_test_script(script, expected = "AUTOYAST OK")
  shell =  File.join(File.dirname(__FILE__),"../spec", script)
  if File.exists?(shell)
    # Copy the file to be tested to /tmp inside the booted box and execute it.
    $vm.inject_file(shell, "/tmp")
    actual = $vm.run_command("source /tmp/#{File.basename(shell)}", stdout: :capture, as: "root")

    # Compare the expected value.
    expect(actual.split("\n").last).to eq(expected)
  end
end

# Copy YaST2 logs from virtual machine to a given directory
#
# The logs will be stored in a tar.gz file. To avoid collisions,
# the compressed file's name will contain a timestamp.
#
# @param [Pennyworth::VM] vm   Virtual machine
# @param [String]         dest Directory where the logs will be stored.
def copy_logs(vm, dest = "log")
  tar_path = "/var/log/YaST2-#{Time.now.strftime('%Y%m%d%H%M%S')}.tar.gz"
  FileUtils.mkdir(dest) unless Dir.exists?(dest)
  vm.run_command("/bin/tar cfz #{tar_path} /var/log/YaST2", as: "root")
  vm.extract_file(tar_path, dest)
end

RSpec.configure do |config|
  config.vagrant_dir = File.join( Dir.getwd, "vagrant" )

  config.before(:all) do
    # Start the previously create vagrant VM - opensuse_vm.
    $vm = start_system(box: "autoyast_vm")

    # This is the only way of execute this after(:all) block
    # before the system is stopped.
    self.class.after(:all) do
      examples = RSpec.world.filtered_examples.values.flatten
      # Copy the logs if some test fails.
      if examples.any?(&:exception)
        copy_logs($vm)
      end
    end
  end
end
