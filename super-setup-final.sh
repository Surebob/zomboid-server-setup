#!/bin/bash
#
# ================================================================= #
#       PROJECT ZOMBOID - APE TOGETHER STRONK FINAL SUPER SCRIPT      #
# ================================================================= #
# This single script handles the complete setup and optional        #
# systemd integration with FIFO support for a Project Zomboid       #
# dedicated server.                                                 #
# ================================================================= #

# --- Script Configuration ---
PZ_USER="pzuser"
PZ_PASSWORD="Supra1122"
PZ_SERVER_DIR="/opt/pzserver"

# --- Colors for Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Safety Check: Ensure script is run as root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run this script with sudo: sudo ./super-setup-final.sh${NC}"
  exit 1
fi

echo -e "${BLUE}--- Starting Project Zomboid Server Super Setup ---${NC}"

# --- 1. System Preparation ---
echo -e "${BLUE}[1/7] Preparing system and installing dependencies...${NC}"
apt-get update
apt-get install -y software-properties-common &>/dev/null
add-apt-repository multiverse -y &>/dev/null
dpkg --add-architecture i386
apt-get update
echo -e "${GREEN}System preparation complete.${NC}"

# --- 2. SteamCMD Installation ---
echo -e "${BLUE}[2/7] Installing SteamCMD...${NC}"
echo "steam steam/question select \"I AGREE\"" | debconf-set-selections
echo "steam steam/license note ''" | debconf-set-selections
apt-get install -y steamcmd &>/dev/null
echo -e "${GREEN}SteamCMD installed.${NC}"

# --- 3. Create Dedicated User & Directories ---
echo -e "${BLUE}[3/7] Creating dedicated user ('$PZ_USER') and server directory...${NC}"
if ! id "$PZ_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$PZ_USER"
    echo "$PZ_USER:$PZ_PASSWORD" | chpasswd
    adduser "$PZ_USER" sudo &>/dev/null
fi
mkdir -p "$PZ_SERVER_DIR"
chown "$PZ_USER":"$PZ_USER" "$PZ_SERVER_DIR"
echo -e "${GREEN}User and directory created.${NC}"

# --- 4. Download Project Zomboid Server ---
echo -e "${BLUE}[4/7] Downloading Project Zomboid server...${NC}"
cat > "/home/$PZ_USER/update_zomboid.txt" <<EOL
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir ${PZ_SERVER_DIR}
login anonymous
app_update 380870 validate
quit
EOL
chown "$PZ_USER":"$PZ_USER" "/home/$PZ_USER/update_zomboid.txt"
sudo -u "$PZ_USER" /usr/games/steamcmd +runscript "/home/$PZ_USER/update_zomboid.txt" &>/dev/null
echo -e "${GREEN}Project Zomboid server downloaded.${NC}"

# --- 5. Configure OS Firewall (iptables) ---
echo -e "${BLUE}[5/7] Configuring OS-level firewall (iptables)...${NC}"
iptables -I INPUT 5 -p udp --dport 16261 -j ACCEPT
iptables -I INPUT 6 -p udp --dport 8766 -j ACCEPT
iptables -I INPUT 7 -p udp --dport 16262:16272 -j ACCEPT
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
apt-get install -y iptables-persistent &>/dev/null
netfilter-persistent save &>/dev/null
echo -e "${GREEN}iptables rules applied and made persistent.${NC}"

# --- 6. The Guided Manual First Run ---
echo -e "${BLUE}[6/7] Starting server for initial password setup...${NC}"
echo -e "${YELLOW}==================== ATTENTION REQUIRED ====================${NC}"
echo -e "The server will now start. It is waiting for you to create a password for the 'admin' user."
echo -e "${YELLOW}Please type your desired admin password below and press Enter. Then confirm it.${NC}"

# Manually create the FIFO file so the start-server.sh doesn't hang waiting for systemd
sudo -u "$PZ_USER" mkfifo "${PZ_SERVER_DIR}/zomboid.control"

# Launch the server in the background, making it interactive for password entry
sudo -u "$PZ_USER" bash -c "cd $PZ_SERVER_DIR && ./start-server.sh"

# We assume the user has finished setting the password and stopped the server with Ctrl+C.
echo -e "${GREEN}Initial password setup is assumed to be complete.${NC}"
# Clean up the manual FIFO file
rm "${PZ_SERVER_DIR}/zomboid.control"

# --- 7. Optional Systemd Setup ---
echo -e "${BLUE}[7/7] Optional: Setup server as a background service?${NC}"
read -p "Do you want to set up Project Zomboid with systemd for auto-start and safe shutdown? (y/n) " -n 1 -r
echo # Move to a new line

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating systemd service and socket files..."

    # Create the zomboid.service file with safe shutdown
    cat >/etc/systemd/system/zomboid.service <<EOL
[Unit]
Description=Project Zomboid Server
After=network.target

[Service]
PrivateTmp=true
Type=simple
User=${PZ_USER}
WorkingDirectory=${PZ_SERVER_DIR}
ExecStart=/bin/sh -c "exec ${PZ_SERVER_DIR}/start-server.sh </opt/pzserver/zomboid.control"
ExecStop=/bin/sh -c "echo save > /opt/pzserver/zomboid.control; sleep 15; echo quit > /opt/pzserver/zomboid.control"
Sockets=zomboid.socket
KillSignal=SIGCONT

[Install]
WantedBy=multi-user.target
EOL

    # Create the zomboid.socket file for FIFO control
    cat >/etc/systemd/system/zomboid.socket <<EOL
[Unit]
BindsTo=zomboid.service

[Socket]
ListenFIFO=/opt/pzserver/zomboid.control
FileDescriptorName=control
RemoveOnStop=true
SocketMode=0660
SocketUser=${PZ_USER}
EOL

    systemctl daemon-reload
    systemctl enable --now zomboid.socket
    echo -e "${GREEN}==================== SERVICE STARTED ====================${NC}"
    echo "The server is now running in the background."
    echo "Use 'systemctl status zomboid' to check it."
    echo "Use 'journalctl -u zomboid -f' to view live logs."
    echo "Use 'systemctl stop zomboid' for a safe shutdown."
    echo -e "${GREEN}=======================================================${NC}"
else
    echo -e "${YELLOW}==================== SETUP FINISHED ====================${NC}"
    echo "To run your server manually, use these commands:"
    echo "1. sudo -u $PZ_USER -i"
    echo "2. cd $PZ_SERVER_DIR"
    echo "3. bash start-server.sh"
    echo -e "${YELLOW}=======================================================${NC}"
fi

echo -e "${GREEN}All done. APE TOGETHER STRONK!${NC}"```
