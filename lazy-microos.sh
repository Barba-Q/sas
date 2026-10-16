#!/bin/bash
set -e

##########################################################################################################
# Description:
# This script will install the plasma desktop, flatpak support and some essential tools on microos
# In fact it's pretty much kalpa with preconfigured nvidia support and flatpak cleanup routine
# 
# Usage:
# After installing microos from .iso or agama installer, log in and type:
# "bash <(curl -sL https://microos.knietief.com)"
# This will download and execute this script
#
# Notes:
# This script was made with AI and is reviewed and tested by human beings on real hardware
#
# Nvidia utilization is considered testing, time will tell how much the additional repository
# will confuse micro-os's automatic update routine. As for now, it works as intended
##########################################################################################################

echo "==> 0. Checking for NVIDIA Hardware..."
TU_EXTRA_ARGS=""
if grep -q "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null; then
  echo "==> NVIDIA GPU detected! Adding repository & enabling auto-license agreement..."
  sudo transactional-update run zypper ar -f https://download.nvidia.com/opensuse/tumbleweed/ NVIDIA_TW || true
  
  # Enable auto-license agreement & auto GPG-key import for working transactional updates
  sudo transactional-update -c run bash -c '
    sed -i "s/#\? *autoAgreeWithLicenses =.*/autoAgreeWithLicenses = yes/" /etc/zypp/zypp.conf 2>/dev/null || true
    sed -i "s/#\? *autoAgreeWithLicenses =.*/autoAgreeWithLicenses = yes/" /etc/zypp/zypper.conf 2>/dev/null || true
    mkdir -p /etc/transactional-update.conf.d
    echo "ZYPPER_AUTO_IMPORT_KEYS=1" > /etc/transactional-update.conf.d/nvidia.conf
  '

  NVIDIA_PKGS="nvidia-open-driver-G06-kmp-default nvidia-glG06 nvidia-computeG06 nvidia-video-G06"
  TU_EXTRA_ARGS="-c"
else
  echo "==> No NVIDIA GPU found. Skipping driver setup."
  NVIDIA_PKGS=""
fi

echo "==> 1. Installing Host packages..."
sudo transactional-update $TU_EXTRA_ARGS run zypper in -y --recommends \
  patterns-kde-kde_plasma \
  plasma6-desktop \
  plasma6-workspace \
  sddm \
  flatpak \
  konsole \
  discover6 \
  discover6-backend-flatpak \
  plasma6-nm \
  plasma6-pa \
  partitionmanager \
  gwenview \
  kate \
  spectacle \
  okular \
  polkit-kde-agent-6 \
  kscreen6 \
  xf86-input-libinput \
  Mesa \
  ark \
  p7zip \
  unrar \
  unzip \
  udisks2 \
  kio-extras \
  dosfstools \
  exfatprogs \
  bluez \
  bluedevil6 \
  dconf \
  breeze-gtk \
  xdg-desktop-portal-gtk \
  xsettingsd \
  cantarell-fonts \
  cups \
  cups-filters \
  cups-pk-helper \
  print-manager \
  sane-backends \
  skanlite \
  firefox \
  gamemode \
  rtkit \
  xdg-utils \
  zenity \
  $NVIDIA_PKGS

echo "==> 2. Setting up SDDM, Bluetooth & Printing inside snapshot..."
sudo transactional-update -c run systemctl set-default graphical.target
sudo transactional-update -c run systemctl enable --force sddm bluetooth cups

echo "==> 3. Configuring global GTK button layout..."
sudo transactional-update -c run bash -c '
  mkdir -p /etc/dconf/db/local.d
  cat << "EOF" > /etc/dconf/db/local.d/00-button-layout
[org/gnome/desktop/wm/preferences]
button-layout="appmenu:minimize,maximize,close"
EOF
  dconf update
'

echo "==> 4. Creating weekly Flatpak cleanup timer..."
sudo transactional-update -c run bash -c '
  mkdir -p /etc/systemd/system
  cat << "EOF" > /etc/systemd/system/flatpak-cleanup.service
[Unit]
Description=Flatpak Unused Runtimes Cleanup

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak uninstall --unused -y
EOF

  cat << "EOF" > /etc/systemd/system/flatpak-cleanup.timer
[Unit]
Description=Run Flatpak Cleanup Weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl enable flatpak-cleanup.timer
'

echo "==> 5. Configuring Firstboot service for Flathub integration..."
sudo transactional-update -c run bash -c '
  cat << "EOF" > /etc/systemd/system/firstboot.service
[Unit]
Description=System Firstboot Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && systemctl disable firstboot.service && rm /etc/systemd/system/firstboot.service"

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable firstboot.service
'

echo "==> 6. Configuring Polkit..."
ACTUAL_USER=${SUDO_USER:-$USER}
sudo transactional-update -c run bash -c "
  cat << EOF > /etc/polkit-1/rules.d/00-nopasswd-user.rules
polkit.addRule(function(action, subject) {
    if (subject.user === \"$ACTUAL_USER\") {
        return polkit.Result.YES;
    }
});
EOF
"

echo "==> Setup complete! Rebooting into new snapshot..."
sudo transactional-update reboot
sudo reboot
