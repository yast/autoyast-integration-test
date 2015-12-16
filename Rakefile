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

require "yast/rake"
require_relative "lib/aytests/tasks/compat.rb"

# remove tarball implementation and create gem for this gemfile
Rake::Task[:tarball].clear
# build the gem package
desc "Build gem package, save RPM sources to package subdirectory"
task :"tarball" do
  version = File.read("VERSION").chomp
  Dir["package/*.tar.bz2"].each do |f|
    rm f
  end

  Dir["package/*.gem"].each do |g|
    rm g
  end

  sh "gem build aytests.gemspec"
  mv "aytests-#{version}.gem", "package"
end

# remove install implementation and install via gem
Rake::Task[:install].clear
desc "Install aytests gem package"
task install: :tarball do
  sh "sudo gem install --local package/aytests*.gem"
end

# this gem uses VERSION file, replace the standard yast implementation
Rake::Task[:'version:bump'].clear

namespace :version do
  task :bump do
    # update VERSION
    version_parts = File.read("VERSION").strip.split(".")
    version_parts[-1] = (version_parts.last.to_i + 1).to_s
    new_version = version_parts.join(".")

    puts "Updating to #{new_version}"
    File.write("VERSION", new_version + "\n")

    # update *.spec file
    spec_file = "package/rubygem-aytests.spec"
    spec = File.read(spec_file)
    spec.gsub!(/^\s*Version:.*$/, "Version:        #{new_version}")
    File.write(spec_file, spec)
  end
end

Rake::Task[:'test:unit'].clear
namespace :test do
  task :unit do
    system "rspec spec"
  end
end

Yast::Tasks.configuration do |conf|
  conf.package_name = "rubygem-aytests"
  #lets ignore license check for now
  conf.skip_license_check << /.*/
end
