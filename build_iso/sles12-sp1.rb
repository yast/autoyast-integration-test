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

require "rubygems"
require "fileutils"

yast_url = "http://download.suse.de/ibs/Devel:/YaST:/Head/SLE-12-SP1/"
iso_url = "http://dist.suse.de/install/SLE-12-SP1-Server-RC1/SLE-12-SP1-Server-DVD-x86_64-RC1-DVD1.iso"

base_dir = File.dirname(__FILE__)
iso_dir = File.join(base_dir, "..", "iso")
iso_path = File.join(iso_dir, File.basename(iso_url))
version = File.basename(__FILE__, ".rb")
cache_dir = File.join(base_dir,"cache")
obs_packages = File.join(base_dir, version+".obs_packages")
local_packages = File.join(base_dir, version+".local_packages")
testing_iso = File.join(base_dir, "../kiwi/iso/obs.iso")

puts "\n**** Cleanup ****"
system("rm -rf #{cache_dir+'/*'}")

Dir.chdir(iso_dir) do
  puts "\n**** Downloading source ISO image ****"
  system "wget --no-clobber #{iso_url}"
end

puts "\n**** Fetching all required packages ****"
system "zypper --root #{cache_dir} ar --no-gpgcheck #{yast_url} download-packages"
system "xargs -a #{obs_packages} zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download"

Dir.chdir(File.join( cache_dir, "download-packages")) do
  puts "\n**** Taking user defined RPMs ****"
  File.open(local_packages).each do |package|
    package.strip!
    unless package.start_with?("#")
      #Remove already downloaded RPMs
      rpm_name = `rpm -qp --qf \"%{NAME}\" #{package}`
      Dir.glob("./**/#{rpm_name}*.rpm").each do |exchange_rpm|
        if `rpm -qp --qf \"%{NAME}\" #{exchange_rpm}` == rpm_name
          puts "\n   Removing #{exchange_rpm}"
          FileUtils.remove_file(exchange_rpm)
        end
      end
      puts "\n   Copying #{package}"
      FileUtils.cp(package,".")
    end
  end

  puts "\n**** Creating DUD ****"
  system "mkdud -c #{version}.dud -d sle12 -i  instsys,repo --prefix=37 --format=tar.gz $(find -name \"\*\.rpm\") ../../dud/"

  puts "\n**** Syncing to disk ****"
  system "sync"
  puts "\nCreated DUD:"
  system "ls -l #{version}.dud"

  puts "\n**** Creating new ISO image with the updated packages ****"
  system "sudo mksusecd -c testing.iso --initrd=#{version}.dud #{iso_path}"

  puts "\n**** Copy new ISO image to veewee/vagrant environment ****"
  puts "\n     destination: #{testing_iso}"
  FileUtils.cp("testing.iso", testing_iso)
end
