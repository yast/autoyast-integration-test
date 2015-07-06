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

#yast_url = "http://download.suse.de/ibs/Devel:/YaST:/SLE-12/SLE_12/"
yast_url = "http://download.suse.de/ibs/Devel:/YaST:/Head/SLE-12-SP1/"
iso_url = "http://dist.suse.de/install/SLE-12-Server-GM/SLE-12-Server-DVD-x86_64-GM-DVD1.iso"

base_dir = File.dirname(__FILE__)
iso_dir = File.join(base_dir, "..", "iso")
iso_path = File.join(iso_dir, File.basename(iso_url))
version = File.basename(__FILE__, ".rb")
cache_dir = File.join(base_dir,"cache")
obs_packages = File.join(base_dir, version+".obs_packages")
boot_dir = File.join(base_dir,"boot_sles12")
local_packages = File.join(base_dir, version+".local_packages")
testing_iso = File.join(base_dir, "../kiwi/iso/testing.iso")

puts "\n**** Cleanup ****"
system("rm -rf #{cache_dir+'/*'}")

Dir.chdir(iso_dir) do
  puts "\n**** Downloading source ISO image ****"
  system "wget --no-clobber #{iso_url}"
end

puts "\n**** Fetching all required packages ****"
system "zypper --root #{cache_dir} ar --no-gpgcheck #{yast_url} download-packages"
system "xargs -a #{obs_packages} zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download"

puts "\n**** Fetching latest grub2 and libzypp packages ****"
system "zypper --root #{cache_dir} rr download-packages"
system "zypper --root #{cache_dir} ar --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-12-SP1:/GA/standard/ download-packages"
system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download grub2-2.02~beta2"
system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download grub2-i386-pc-2.02~beta2"
system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download libzypp"
system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download libsolv-tools"
system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download zypper"

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

  puts "\n**** Creating DUD: Updating /etc/zypp/zypp.conf ****"
  system "mkdud -c zypp.dud -d sle12 -i  instsys,repo --prefix=37 ../../dud/"

  puts "\n**** Creating DUD with updated packages ****"
  system "find . -name \"*.rpm\"|xargs mkdud -c packages.dud -d sle12 -i instsys,repo --prefix=37"

  puts "\n**** Creating DUD from zypp and packages ****"
  system "mkdud -c #{version}.dud -d sle12 -i  instsys,repo --prefix=37 packages.dud zypp.dud"

  puts "\n**** Creating new ISO image with the updated packages ****"
  system "sudo mksusecd -c testing.iso --initrd=#{version}.dud #{iso_path} #{boot_dir}"

  puts "\n**** Copy new ISO image to veewee/vagrant environment ****"
  puts "\n     destination: #{testing_iso}"
  FileUtils.cp("testing.iso", testing_iso)
end
