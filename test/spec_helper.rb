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
  require_relative "helpers"
  config.include Helpers

  unless ENV["AYTESTS_LOCAL"] == "true"
    require "ay_tests"

    config.before(:all) do
      AYTests.base_dir = Pathname.new(File.dirname(__FILE__)).join("..")
      $vm = AYTests::VagrantRunner.new(AYTests.base_dir.join("vagrant"), AYTests.provider)
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
