#
# spec file for package rubygem-aytests
#
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           rubygem-aytests
Version:        1.0.24
Release:        0
%define mod_name aytests
%define mod_full_name %{mod_name}-%{version}
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  ruby-macros >= 5
BuildRequires:  %{ruby}
BuildRequires:  %{rubygem gem2rpm}
Url:            http://github.org/yast/autoyast-integration-test
Source:         http://rubygems.org/gems/%{mod_full_name}.gem
Summary:        AutoYaST integration tests framework
License:        GPL-3.0
Group:          Development/Languages/Ruby

# These dependencies are included in the package/gem2rpm.yml file.
Requires:       mksusecd
Requires:       mkdud
Requires:       virt-install

%description
This gem contains the framework needed to run AutoYaST integration tests.

%prep

%build

%install
%gem_install \
  --symlink-binaries \
  --doc-files="README.md" \
  -f

%gem_packages

%changelog
