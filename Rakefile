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


def run_ay_tests(cmd)
  $stderr.puts "rake interface is deprecated. Please, use ay-tests script "\
    "directly. Anyway, the command will be run."
  puts cmd
  system cmd
end

def iso_repo
  if `hostname --domain`.chomp == "suse.cz"
    "http://fallback.suse.cz"
  else
    "http://dist.suse.de"
  end
end

#
# Compatibility tasks
#
task :test, :name do |name, args|
  run_ay_tests("./bin/ay-tests test #{args[:name]}")
end

task :build_iso, :name do |name, args|
  run_ay_tests("./bin/ay-tests build_iso #{args[:name]}")
end

# Cleaning tasks
# Temporary files
task :clean do
  run_ay_tests("./bin/ay-tests clean")
end

# Final products
task :clobber do
  run_ay_tests("./bin/ay-tests clobber")
end
