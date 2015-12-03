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


RSpec.configure do |config|
  require "aytests/test_helpers"
  config.include AYTests::TestHelpers

  unless ENV["AYTESTS_LOCAL"] == "true"
    require "aytests"
    AYTests.work_dir = ENV["AYTESTS_WORK_DIR"]

    config.before(:all) do
      $vm = AYTests::VagrantRunner.new(base_dir: AYTests.base_dir,
        dir: AYTests.work_dir.join("vagrant"), driver: AYTests.provider)
      # Start the previously create vagrant VM - autoyast_vm
      start_vm($vm)
    end

    config.after(:all) do
      examples = RSpec.world.filtered_examples.values.flatten
      # Copy the logs if some test fails.
      copy_logs($vm) if examples.any?(&:exception)
      shutdown_vm($vm)
    end
  end
end

RSpec.shared_examples "test_scripts" do |list|
  require "aytests"
  list_path = Pathname.pwd.join("#{list}.list")

  File.readlines(list_path).each do |line|
    test, description = line.strip.split("#", 2)
    next if test.nil?

    it "#{description || test}" do
      run_test_script(Pathname.pwd.join(test.strip))
    end
  end
end
