echo 'Enter WiFi ID: '
read SSIDName
echo 'Enter WiFi Password (min 8 chars): '
read SSIDPsw

if [ ${#SSIDPsw} -lt 8 ]; then
  echo "Error: Wi-Fi password must be at least 8 characters!"
  exit 1
fi

echo 'Installing WiFi services...'
sudo apt install -y dnsmasq hostapd

# Configurer IP statique pour wlan0
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOL
interface wlan0
    static ip_address=172.24.1.1/24
    nohook wpa_supplicant
EOL
sudo service dhcpcd restart

# Sauvegarder l'ancien fichier dnsmasq
if [ -f /etc/dnsmasq.conf ]; then
    sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
fi

# Configuration DHCP avec dnsmasq
sudo tee /etc/dnsmasq.conf > /dev/null <<EOL
interface=wlan0
dhcp-range=172.24.1.50,172.24.1.150,255.255.255.0,12h
EOL
sudo systemctl restart dnsmasq

# Configuration du point d'accès Wi-Fi
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOL
interface=wlan0
driver=nl80211
ssid=${SSIDName}
wpa_passphrase=${SSIDPsw}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOL

# Assurer que hostapd utilise ce fichier
sudo tee /etc/default/hostapd > /dev/null <<EOL
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOL

# Activer et démarrer le service
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

# Activer le routage pour partager Internet
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configurer NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

echo "WiFi Access Point setup completed!"
