#!/usr/bin/env python3
"""
TailChase Logger v1.2 - Jerry's custom logging service
WARNING: Contains command injection vulnerability
Run on Kali to test, or deploy on VM port 8080
"""
import socket
import os
import sys

def handle_client(conn, addr):
    try:
        conn.send(b"TailChase Log Service v1.2\n")
        conn.send(b"Format: LOG|<hostname>|<message>\n")

        data = conn.recv(4096).decode().strip()
        if not data:
            conn.close()
            return

        if data.startswith("LOG|"):
            parts = data.split("|", 2)
            if len(parts) == 3:
                hostname = parts[1]
                message = parts[2]

                # VULNERABLE: Command injection
                try:
                    result = os.popen(f"getent hosts {hostname} 2>&1 || echo 'Unknown'").read()
                    conn.send(f"Message logged: {message}\n\n".encode())
                    conn.send(f"Host lookup: {result}\n".encode())
                except Exception as e:
                    conn.send(f"Error: {e}\n".encode())
            else:
                conn.send(b"Invalid format. Use: LOG|<hostname>|<message>\n")
        else:
            conn.send(b"Unknown command. Use: LOG|<hostname>|<message>\n")
    except:
        pass
    finally:
        conn.close()

def main():
    HOST = '0.0.0.0'
    PORT = 8080

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(5)
    print(f"[+] TailChase Logger running on {PORT}")

    while True:
        conn, addr = server.accept()
        print(f"[*] Connection from {addr}")
        handle_client(conn, addr)

if __name__ == '__main__':
    main()
