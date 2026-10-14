#!/bin/bash
set -e

echo "==> 0. Checking for NVIDIA Hardware..."
if grep -q "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null; then
  echo "==> NVIDIA GPU detected! Installing Driver with open kernel modules (G06)..."
  
  # Add repo
  sudo transactional-update run zypper ar -f https://download.nvidia.com/opensuse/tumbleweed/ NVIDIA_TW || true
  
  # install drivers
  NVIDIA_PKGS="nvidia-open-driver-G06-kmp-default nvidia-glG06 nvidia-computeG06 nvidia-video-G06"
else
  echo "==> No NVIDIA GPU found. skipping."
  NVIDIA_PKGS=""
fi

echo "==> 1. Install desktop"
sudo transactional-update pkg install \
  patterns-kde-kde_plasma \
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
  $NVIDIA_PKGS

echo "==> 2. Set up SDDM"
sudo systemctl set-default graphical.target
sudo systemctl enable --force sddm bluetooth

echo "==> 3. Create Flatpak cleanup"
sudo mkdir -p /etc/systemd/system

cat << 'EOF' | sudo tee /etc/systemd/system/flatpak-cleanup.service > /dev/null
[Unit]
Description=Flatpak Unused Runtimes Cleanup

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak uninstall --unused -y
EOF

cat << 'EOF' | sudo tee /etc/systemd/system/flatpak-cleanup.timer > /dev/null
[Unit]
Description=Run Flatpak Cleanup Weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable flatpak-cleanup.timer

echo "==> 4. Firstboot for flatpak configuration"
cat << 'EOF' | sudo tee /etc/systemd/system/oma-firstboot.service > /dev/null
[Unit]
Description=Oma System Firstboot Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
  systemctl disable oma-firstboot.service && \
  rm /etc/systemd/system/oma-firstboot.service'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable oma-firstboot.service

echo "==> Setup complete, rebooting ..."
sudo reboot
