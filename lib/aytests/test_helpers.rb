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

require "open3"
require "pathname"

module AYTests
  module TestHelpers
    # Run a test script
    #
    # Run a script in the SUT and check if the last line matches
    # the expected value. The script is supposed to live on test/
    # directory.
    #
    # If ENV["AYTESTS_LOCAL"] == "true" then #local_run_test_script
    # will be called. Otherwise, #remote_run_test_script will be used.
    #
    # @param [String] script   Script name
    # @param [String] expected Expected value of stdout last line
    def run_test_script(shell, expected = "AUTOYAST OK")
      # Check if the script exists
      expect(File.exists?(shell)).to eq(true), "test script does not exists: #{shell}"

      if ENV["AYTESTS_LOCAL"] == "true"
        local_run_test_script(shell, expected)
      else
        remote_run_test_script($vm, shell, expected)
      end
    end

    # Run a test script in a SUT
    #
    # Run a script given the SUT is a virtual machine.
    #
    # @param [AYTests::VagrantRunner] runner   Virtual machine runner
    # @param [String]                 script   Full path to the script
    # @param [String]                 expected Expected value of stdout last line
    def remote_run_test_script(vm, path, expected = "AUTOYAST OK")
      result = vm.run(path, sudo: true)
      expect(result[:stdout].split("\n").last).to eq(expected), proc { result[:stderr] }
    end

    # Run a test script in a SUT
    #
    # Run a script given the SUT is the local machine.
    #
    # @param [String]                 script   Full path to the script
    # @param [String]                 expected Expected value of stdout last line
    def local_run_test_script(path, expected = "AUTOYAST OK")
      stdout, stderr, _status = Open3.capture3("sudo sh #{path}")
      expect(stdout.split("\n").last).to eq(expected), proc { stderr }
    end

    # Start a virtual machine
    #
    # @param [AYTests::VagrantRunner] runner Virtual machine runner
    def start_vm(vm)
      vm.cleanup
      vm.start
    end

    # Shutdown and clean up a virtual machine
    #
    # @param [AYTests::VagrantRunner] runner Virtual machine runner
    def shutdown_vm(vm)
      vm.stop
      vm.cleanup
    end
  end
end
