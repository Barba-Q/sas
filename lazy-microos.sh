#!/bin/bash
set -e

echo "==> 1. Install desktop"
sudo transactional-update pkg install \
  patterns-kde-kde_plasma \
  sddm \
  flatpak \
  konsole \
  discover6 \
  discover6-backend-flatpak \
  plasma6-nm \
  plasma6-pa \
  polkit-kde-agent-6 \
  kscreen6 \
  xf86-input-libinput \
  Mesa

echo "==> 2. Set up SDDM"
sudo systemctl set-default graphical.target
sudo systemctl enable --force sddm

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

echo "==> 4. Firstboot for flatpak configuration and firefox installation"
cat << 'EOF' | sudo tee /etc/systemd/system/oma-firstboot.service > /dev/null
[Unit]
Description=Oma System Firstboot Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
  flatpak install -y flathub org.mozilla.firefox && \
  systemctl disable oma-firstboot.service && \
  rm /etc/systemd/system/oma-firstboot.service'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable oma-firstboot.service

echo "==> Setup complete, rebooting ..."
sudo reboot
