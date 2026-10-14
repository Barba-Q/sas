#!/bin/bash
set -e

echo "==> 0. Checking for NVIDIA Hardware..."
TU_EXTRA_ARGS=""
if grep -q "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null; then
  echo "==> NVIDIA GPU detected! Adding repository..."
  sudo transactional-update run zypper ar -f https://download.nvidia.com/opensuse/tumbleweed/ NVIDIA_TW || true
  NVIDIA_PKGS="nvidia-open-driver-G06-kmp-default nvidia-glG06 nvidia-computeG06 nvidia-video-G06"
  TU_EXTRA_ARGS="-c"
else
  echo "==> No NVIDIA GPU found. Skipping driver setup."
  NVIDIA_PKGS=""
fi

echo "==> 1. Installing Host packages (with KDE Plasma recommendations)..."
sudo transactional-update $TU_EXTRA_ARGS run zypper in -y --recommends \
  patterns-kde-kde_plasma \
  plasma6-desktop \
  plasma6-workspace \
  sddm \
  bluez \
  bluedevil6 \
  flatpak \
  firefox \
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
  $NVIDIA_PKGS

echo "==> 2. Setting up SDDM & Bluetooth inside snapshot..."
sudo transactional-update -c run systemctl set-default graphical.target
sudo transactional-update -c run systemctl enable --force sddm bluetooth

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
  cat << "EOF" > /etc/systemd/system/oma-firstboot.service
[Unit]
Description=Oma System Firstboot Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && systemctl disable oma-firstboot.service && rm /etc/systemd/system/oma-firstboot.service"

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable oma-firstboot.service
'

echo "==> Setup complete! Rebooting into new snapshot..."
sudo transactional-update reboot
