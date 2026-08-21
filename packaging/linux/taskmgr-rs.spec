# +-------------------------------------------------------------------------
#
#   taskmgr-rs - RPM 打包规格
#
#   文件:       packaging/linux/taskmgr-rs.spec
#
#   日期:       2026年08月20日
#   环境:       Fedora/RHEL Linux x64/ARM64；RPM 4
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   RPM Packaging Guide；Filesystem Hierarchy Standard；polkit action
# --------------------------------------------------------------------------

%global debug_package %{nil}
%global application_id org.taskmgr_rs.TaskManager
%global extension_uuid window-provider@org.taskmgr_rs.TaskManager

Name:           taskmgr-rs
Version:        %{package_version}
Release:        1%{?dist}
Summary:        Classic cross-platform task manager
License:        MIT
URL:            https://github.com/JamesLinYJ/taskmgr-rs-desktop
Requires:       gtk3
Requires:       xz-libs
Requires:       polkit

%description
Flutter desktop interface backed by native Rust system collectors for
Windows and Linux.

%prep

%build

%install
install -d %{buildroot}/usr/lib/taskmgr-rs
cp -a %{bundle_dir}/. %{buildroot}/usr/lib/taskmgr-rs/
install -Dpm0755 %{helper_path} %{buildroot}/usr/libexec/taskmgr-rs/taskmgr-helper
install -Dpm0755 %{launcher_path} %{buildroot}/usr/bin/taskmgr_rs
install -Dpm0644 %{desktop_path} %{buildroot}/usr/share/applications/%{application_id}.desktop
install -Dpm0644 %{policy_path} %{buildroot}/usr/share/polkit-1/actions/%{application_id}.policy
install -d %{buildroot}/usr/share/gnome-shell/extensions/%{extension_uuid}
install -m 0644 %{extension_path}/metadata.json %{extension_path}/extension.js \
    %{buildroot}/usr/share/gnome-shell/extensions/%{extension_uuid}
install -d %{buildroot}/usr/share/icons/hicolor
cp -a %{icons_path}/. %{buildroot}/usr/share/icons/hicolor/
install -Dpm0644 %{license_path} %{buildroot}/usr/share/licenses/taskmgr-rs/LICENSE

%post
update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
gtk-update-icon-cache -q /usr/share/icons/hicolor >/dev/null 2>&1 || :

%postun
update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
gtk-update-icon-cache -q /usr/share/icons/hicolor >/dev/null 2>&1 || :

%files
%license /usr/share/licenses/taskmgr-rs/LICENSE
/usr/bin/taskmgr_rs
/usr/lib/taskmgr-rs/
/usr/libexec/taskmgr-rs/taskmgr-helper
/usr/share/applications/%{application_id}.desktop
/usr/share/icons/hicolor/*/apps/%{application_id}.png
/usr/share/gnome-shell/extensions/%{extension_uuid}/
/usr/share/polkit-1/actions/%{application_id}.policy

%changelog
* Thu Aug 20 2026 JamesLinYJ - 0.3.0-1
- Initial cross-platform Flutter desktop package.
