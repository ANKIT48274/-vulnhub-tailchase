# TailChase VM - Packer Template
# Full automated build for VirtualBox / Debian 12
# Author: Ankit Patidar
#
# Usage:
#   1. Install packer:  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
#                       sudo apt-add-repository "deb https://apt.releases.hashicorp.com $(lsb_release -cs) main"
#                       sudo apt-get update && sudo apt-get install packer
#   2. Build:           sudo packer build -force tailchase.pkr.hcl
#
# OR run manual script instead:
#   sudo bash full_auto_build.sh

variable "vm_name" {
  type    = string
  default = "TailChase"
}

variable "headless" {
  type    = string
  default = "false"
}

variable "ssh_password" {
  type    = string
  default = "tailchase_admin"
}

source "virtualbox-iso" "tailchase" {
  vm_name          = "${var.vm_name}"
  guest_os_type    = "Debian_64"
  memory           = 1024
  cpus             = 1
  disk_size        = 8192
  http_directory   = "http"
  boot_wait        = "10s"

  # Boot command with preseed URL
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg",
    "<enter>"
  ]

  # Debian 12 ISO
  iso_url      = "/home/ankit/Documents/iso file/debian-12.9.0-amd64-netinst.iso"
  iso_checksum = "none"

  ssh_username           = "root"
  ssh_password           = "${var.ssh_password}"
  ssh_handshake_attempts = "300"
  ssh_wait_timeout       = "1800s"
  ssh_port               = 22

  # Network (host-only)
  network = "HostInterfaceNetworking-vboxnet0"
  hostonly_adapter_type = "host_only"

  # Export settings
  format                = "ova"
  keep_registered       = true
  skip_export           = false
  output_directory      = "/home/ankit/TailChase/output"
  export_output_path    = "/home/ankit/TailChase/TailChase_v1.0.ova"
  vboxmanage            = [
    ["modifyvm", "${var.vm_name}", "--nic1", "hostonly"],
    ["modifyvm", "${var.vm_name}", "--hostonlyadapter1", "vboxnet0"],
    ["modifyvm", "${var.vm_name}", "--audio", "none"],
    ["modifyvm", "${var.vm_name}", "--usb", "off"],
    ["modifyvm", "${var.vm_name}", "--memory", "1024"],
  ]
}

build {
  sources = ["source.virtualbox-iso.tailchase"]

  # Step 1: Apply the setup script
  provisioner "file" {
    source      = "/home/ankit/TailChase/setup_vuln.sh"
    destination = "/tmp/setup_vuln.sh"
  }

  # Step 2: Run the setup script
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/setup_vuln.sh",
      "cd /tmp && bash setup_vuln.sh 2>&1 | tee /var/log/setup.log",
      "echo '=== SETUP COMPLETE ==='"
    ]
  }

  # Step 3: Verify the build
  provisioner "shell" {
    inline = [
      "echo '=== SERVICE STATUS ==='",
      "systemctl status vsftpd --no-pager 2>&1 | head -5",
      "systemctl status nginx --no-pager 2>&1 | head -5",
      "systemctl status smbd --no-pager 2>&1 | head -5",
      "echo '=== USER FLAG ==='",
      "cat /home/devops/user.txt 2>&1 | head -3",
      "echo '=== ROOT FLAG ==='",
      "cat /root/root.txt 2>&1 | head -3",
      "echo '=== PORTS ==='",
      "ss -tlnp 2>&1",
    ]
  }

  # Step 4: Cleanup
  provisioner "shell" {
    inline = [
      "apt clean",
      "rm -rf /var/cache/apt/* /root/.cache/*",
      "> /root/.bash_history",
      "> /home/devops/.bash_history 2>/dev/null || true",
      "> /home/secops/.bash_history 2>/dev/null || true",
      "echo '=== BUILD COMPLETE ==='",
    ]
  }

  # Post-process: export to OVA
  post-processor "shell-local" {
    inline = [
      "echo '[+] OVA exported to /home/ankit/TailChase/TailChase_v1.0.ova'",
      "echo '[+] Build complete!'"
    ]
  }
}
