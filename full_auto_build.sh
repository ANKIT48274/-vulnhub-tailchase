#!/bin/bash
# ===========================================
# TailChase VM - Full Automated Build Script
# Author: Ankit Patidar
# This script builds the ENTIRE VM from scratch
# Run: sudo bash full_auto_build.sh
# ===========================================

set -e

VMNAME="TailChase"
VDI_PATH="$HOME/VirtualBox VMs/$VMNAME/$VMNAME.vdi"
ISO_PATH="/home/ankit/Documents/iso file/debian-12.9.0-amd64-netinst.iso"
SETUP_SCRIPT="/home/ankit/TailChase/setup_vuln.sh"

echo ""
echo " ╔═══════════════════════════════════════════╗"
echo " ║     TAILCHASE VM - FULL AUTO BUILD        ║"
echo " ║     Author: Ankit Patidar                 ║"
echo " ╚═══════════════════════════════════════════╝"
echo ""

# === Step 1: Clean up any existing VM ===
echo "[1/8] Cleaning up existing VM..."
VBoxManage unregistervm "$VMNAME" --delete 2>/dev/null || true
rm -rf "$HOME/VirtualBox VMs/$VMNAME" 2>/dev/null || true
echo "  [✓] Cleaned"

# === Step 2: Create VM ===
echo "[2/8] Creating VM..."
VBoxManage createvm --name "$VMNAME" --ostype "Debian_64" --register
VBoxManage modifyvm "$VMNAME" --memory 1024 --vram 16 --cpus 1
VBoxManage modifyvm "$VMNAME" --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage modifyvm "$VMNAME" --audio none --usb off
VBoxManage modifyvm "$VMNAME" --ioapic on
VBoxManage modifyvm "$VMNAME" --boot1 dvd --boot2 disk
echo "  [✓] VM created"

# === Step 3: Create and attach disk ===
echo "[3/8] Creating hard disk..."
VBoxManage createhd --filename "$VDI_PATH" --size 8192
VBoxManage storagectl "$VMNAME" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "$VMNAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$VDI_PATH"
echo "  [✓] Disk created (8GB)"

# === Step 4: Attach ISO ===
echo "[4/8] Attaching Debian ISO..."
VBoxManage storagectl "$VMNAME" --name "IDE" --add ide
VBoxManage storageattach "$VMNAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"
echo "  [✓] ISO attached"

# === Step 5: Create preseed ISO (auto-install) ===
echo "[5/8] Creating preseed ISO for auto-install..."
mkdir -p /tmp/deb-preseed
cat > /tmp/deb-preseed/preseed.cfg << 'PRESEED'
# TailChase VM - Fully Automated Debian 12 Preseed
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/choose_interface select auto
d-i netcfg/dhcp_timeout string 60
d-i netcfg/get_hostname string tailchase
d-i netcfg/get_domain string local
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i passwd/root-login boolean true
d-i passwd/root-password password tailchase_admin
d-i passwd/root-password-again password tailchase_admin
d-i passwd/user-fullname string admin
d-i passwd/username string admin
d-i passwd/user-password password admin123
d-i passwd/user-password-again password admin123
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i clock-setup/ntp boolean true
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i base-installer/install-recommends boolean true
d-i apt-setup/use_mirror boolean true
d-i apt-setup/services-select multiselect security, updates
tasksel tasksel/first multiselect ssh-server, standard
d-i pkgsel/include string sudo curl wget
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default
d-i finish-install/reboot_in_progress note
PRESEED

# Check if we can install xorriso
if ! which xorriso >/dev/null 2>&1; then
    echo "  [!] xorriso not installed, attempting to install..."
    apt-get install -y xorriso 2>/dev/null || {
        echo "  [!] Cannot install xorriso. Will try manual method."
    }
fi

if which xorriso >/dev/null 2>&1; then
    # Create bootable preseed ISO
    cd /tmp/deb-preseed
    mkdir -p isolinux
    echo "Preseed for TailChase" > isolinux/message.txt

    xorriso -as mkisofs -o /tmp/preseed.iso \
        -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        /tmp/deb-preseed 2>/dev/null || {
        echo "  [!] xorriso failed, continuing without preseed..."
    }

    if [ -f /tmp/preseed.iso ]; then
        # Attach preseed as secondary ISO
        VBoxManage storageattach "$VMNAME" --storagectl "IDE" --port 1 --device 0 --type dvddrive --medium /tmp/preseed.iso 2>/dev/null || true
        echo "  [✓] Preseed ISO created and attached"
    fi
else
    echo "  [-] Skipping preseed ISO (xorriso not available)"
    echo "  [!] Manual install needed:"
    echo "      1. Start the VM in VirtualBox GUI"
    echo "      2. Install Debian 12 with these settings:"
    echo "         - Hostname: tailchase"
    echo "         - Root pass: tailchase_admin"
    echo "         - User: admin / admin123"
    echo "         - Packages: SSH server + Standard utilities"
    echo "      3. After install, run:"
    echo "         curl -sL http://192.168.56.1:8000/setup_vuln.sh | bash"
fi

echo "  [✓] Auto-install configured"

# === Step 6: Start VM and wait for install ===
echo "[6/8] Starting VM installation..."
echo "  [!] This will take 10-20 minutes..."
echo "  [!] Press Ctrl+C after install to continue this script"
echo ""

# Start VM headless
VBoxManage startvm "$VMNAME" --type headless 2>/dev/null || {
    echo "  [!] Headless start failed. Starting GUI..."
    VBoxManage startvm "$VMNAME" --type gui &
}

echo "  [✓] VM started"
echo "  [!] VM is running in the background"
echo ""
echo "  === IMPORTANT ==="
echo "  If preseed doesn't work, install Debian 12 manually:"
echo "  - Language: English"
echo "  - Hostname: tailchase"
echo "  - Root pass: tailchase_admin"
echo "  - User: admin / admin123"
echo "  - Partition: Guided - entire disk"
echo "  - Packages: SSH server + Standard system utilities"
echo "  - NO Desktop Environment"
echo ""

# Wait for VM to be ready (poll SSH)
echo "  Waiting for SSH to become available..."
for i in $(seq 1 120); do
    sleep 10
    IP=$(VBoxManage guestproperty get "$VMNAME" "/VirtualBox/GuestInfo/Net/0/V4/IP" 2>/dev/null | awk '{print $NF}')
    if [ -n "$IP" ] && [ "$IP" != "No value set!" ]; then
        echo "  [✓] VM IP: $IP"
        break
    fi
done

# Try to find IP via other method
if [ -z "$IP" ] || [ "$IP" = "No value set!" ]; then
    echo "  [!] Cannot get IP from guest properties"
    echo "  [!] Check VirtualBox GUI for VM IP"
    echo ""
    echo "  When VM is ready, run manually:"
    echo ""
    echo "  scp $SETUP_SCRIPT root@<VM_IP>:/tmp/"
    echo "  ssh root@<VM_IP> 'bash /tmp/setup_vuln.sh'"
    echo ""
    echo "  Or if you have a web server:"
    echo "  cd $(dirname $SETUP_SCRIPT)"
    echo "  python3 -m http.server 8000"
    echo "  # On VM: curl http://192.168.56.1:8000/setup_vuln.sh | bash"
    exit 0
fi

# === Step 7: Deploy setup script ===
echo "[7/8] Deploying setup script to VM..."
sshpass -p "tailchase_admin" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$SETUP_SCRIPT" root@$IP:/tmp/setup_vuln.sh 2>/dev/null || {
    echo "  [!] sshpass not available, trying manual scp..."
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SETUP_SCRIPT" root@$IP:/tmp/setup_vuln.sh
}

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$IP "chmod +x /tmp/setup_vuln.sh && cd /tmp && bash setup_vuln.sh" 2>&1 || {
    echo "  [!] SSH command failed. Run manually:"
    echo "  ssh root@$IP 'bash /tmp/setup_vuln.sh'"
}

echo "  [✓] Setup script deployed"

# === Step 8: Export OVA ===
echo "[8/8] Exporting OVA..."
VBoxManage controlvm "$VMNAME" poweroff 2>/dev/null || true
sleep 5

# Compact disk
VBoxManage modifymedium disk "$VDI_PATH" --compact 2>/dev/null || true

# Export
VBoxManage export "$VMNAME" \
    --output "/home/ankit/TailChase/TailChase_v1.0.ova" \
    --ovf20 \
    --vsys 0 \
    --vmname "TailChase" \
    --product "TailChase v1.0" \
    --producturl "https://github.com/ANKIT48274/vulnhub-tailchase" \
    --vendor "Ankit Patidar" \
    --vendorurl "https://github.com/ANKIT48274" \
    --description "TailChase v1.0 - An OSCP-level medium difficulty CTF VM. Network services exploitation, SMB, FTP, Flask session forging, race condition privesc. Author: Ankit Patidar"

echo ""
echo " ╔═══════════════════════════════════════════╗"
echo " ║     BUILD COMPLETE!                        ║"
echo " ║     Author: Ankit Patidar                  ║"
echo " ╚═══════════════════════════════════════════╝"
echo ""
echo "  OVA: /home/ankit/TailChase/TailChase_v1.0.ova"
echo "  Checksum:"
sha256sum "/home/ankit/TailChase/TailChase_v1.0.ova" 2>/dev/null || true
echo ""
echo "  Next steps:"
echo "  1. Import OVA to VirtualBox"
echo "  2. Set Host-Only adapter"
echo "  3. Boot and hack!"
echo ""
