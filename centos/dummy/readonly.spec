%define debug_package %{nil}
%define product_family FitOS
#%define variant_titlecase Server
#%define variant_lowercase server
%define release_name V3R3-beta
%define base_release_version 1
#%define full_release_version 7
%define dist_release_version 7
#%define upstream_rel 7.4
#%define centos_rel 4.1708
#define beta Beta
%define dist .el%{dist_release_version}.centos
#%define build_timestamp %(date +"%Y%m%d")
#%define built_stamp %(date +"%Y-%m-%d %H:%M")

Name:           readonly
Version:        %{base_release_version}
Release:        0%{?dist}
Summary:        %{product_family} release file
Group:          System Environment/Base
Vendor:         Fiberhome
License:        GPLv2
Provides:       readonly = %{version}-%{release}%{dist}
Source0:        readonly.tar.gz

%description
%{product_family} release files: dummy.iso, which is used to mounting read-only dir to avoid local writing

%prep
%setup -q -n readonly

%build
echo OK

%pre

%install

mkdir -p %{buildroot}/tmp
install -m 644 dummy.iso %{buildroot}/tmp

%post
mount -o loop /tmp/dummy.iso /var/lib/libvirt/sanlock

%clean
rm -rf %{buildroot}

%files
%defattr(0644,root,root,0755)
/tmp/dummy.iso

%changelog
* Fri Jun 1 2018 Add V3R3-beta readonly to fix Bug#3087
-
