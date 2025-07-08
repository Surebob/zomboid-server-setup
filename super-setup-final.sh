#!/bin/bash
#
# ================================================================= #
#       PROJECT ZOMBOID - APE TOGETHER STRONK SUPER SCRIPT      #
#                 (Ape Lord Edition - Now more robust!)           #
# ================================================================= #

# --- Script Configuration ---
PZ_USER="pzuser"
PZ_PASSWORD="Supra1122"
PZ_SERVER_DIR="/opt/pzserver"
PZ_MEMORY="3g" 

# --- Colors for Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Safety Check ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run this script with sudo: sudo ./super-setup-final.sh${NC}"
  exit 1
fi

echo -e "${BLUE}--- Starting Project Zomboid Server Super Setup (Ape Lord Mode) ---${NC}"

# --- 1. System Preparation & Non-Interactive Setup ---
echo -e "${BLUE}[1/8] Setting up non-interactive frontend...${NC}"
# This prevents apt from asking interactive questions (like 'Which services to restart?')
export DEBIAN_FRONTEND=noninteractive

echo -e "${BLUE}[2/8] Preparing system and installing dependencies...${NC}"
apt-get update -y
apt-get install -y software-properties-common
add-apt-repository multiverse -y
dpkg --add-architecture i386
apt-get update -y
echo -e "${GREEN}System preparation complete.${NC}"

# --- 3. SteamCMD Installation ---
echo -e "${BLUE}[3/8] Installing SteamCMD...${NC}"
# Pre-accept the Steam license
echo "steam steam/question select \"I AGREE\"" | debconf-set-selections
echo "steam steam/license note ''" | debconf-set-selections
# Install steamcmd, automatically saying 'yes'
apt-get install -y steamcmd
echo -e "${GREEN}SteamCMD installed.${NC}"

# --- 4. Create Dedicated User & Directories ---
echo -e "${BLUE}[4/8] Creating dedicated user ('$PZ_USER') and server directory...${NC}"
if ! id "$PZ_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$PZ_USER"
    echo "$PZ_USER:$PZ_PASSWORD" | chpasswd
    adduser "$PZ_USER" sudo
fi
mkdir -p "$PZ_SERVER_DIR"
chown "$PZ_USER":"$PZ_USER" "$PZ_SERVER_DIR"
echo -e "${GREEN}User and directory created.${NC}"

# --- 5. Download Project Zomboid Server ---
echo -e "${BLUE}[5/8] Downloading Project Zomboid server...${NC}"
cat > "/home/$PZ_USER/update_zomboid.txt" <<EOL
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir ${PZ_SERVER_DIR}
login anonymous
app_update 380870 validate
quit
EOL
chown "$PZ_USER":"$PZ_USER" "/home/$PZ_USER/update_zomboid.txt"
sudo -u "$PZ_USER" /usr/games/steamcmd +runscript "/home/$PZ_USER/update_zomboid.txt"
echo -e "${GREEN}Project Zomboid server downloaded.${NC}"

# --- 6. Pre-configure Server Memory ---
echo -e "${BLUE}[6/8] Pre-configuring server memory to ${PZ_MEMORY}...${NC}"
# (The rest of the script for memory config, firewall, and systemd setup follows...)
cat > "${PZ_SERVER_DIR}/ProjectZomboid64.json" <<EOL
{
	"mainClass": "zombie/network/GameServer",
	"classpath": [ "java/.", "java/istack-commons-runtime.jar", "java/jassimp.jar", "java/javacord-2.0.17-shaded.jar", "java/javax.activation-api.jar", "java/jaxb-api.jar", "java/jaxb-runtime.jar", "java/lwjgl.jar", "java/lwjgl-natives-linux.jar", "java/lwjgl-glfw.jar", "java/lwjgl-glfw-natives-linux.jar", "java/lwjgl-jemalloc.jar", "java/lwjgl-jemalloc-natives-linux.jar", "java/lwjgl-opengl.jar", "java/lwjgl-opengl-natives-linux.jar", "java/lwjgl_util.jar", "java/sqlite-jdbc-3.27.2.1.jar", "java/trove-3.0.3.jar", "java/uncommons-maths-1.2.3.jar", "java/commons-compress-1.18.jar" ],
	"vmArgs": [ "-Djava.awt.headless=true", "-Xmx${PZ_MEMORY}", "-Dzomboid.steam=1", "-Dzomboid.znetlog=1", "-Djava.library.path=linux64/:natives/", "-Djava.security.egd=file:/dev/urandom", "-XX:+UseZGC", "-XX:-OmitStackTraceInFastThrow" ]
}
EOL
chown "$PZ_USER":"$PZ_USER" "${PZ_SERVER_DIR}/ProjectZomboid64.json"
echo -e "${GREEN}Server memory configuration saved.${NC}"

# --- 7. Configure OS Firewall (iptables) ---
echo -e "${BLUE}[7/8] Configuring OS-level firewall (iptables)...${NC}"
iptables -I INPUT 5 -p udp --dport 16261 -j ACCEPT
iptables -I INPUT 6 -p udp --dport 8766 -j ACCEPT
iptables -I INPUT 7 -p udp --dport 16262:16272 -j ACCEPT
apt-get install -y iptables-persistent
netfilter-persistent save
echo -e "${GREEN}iptables rules applied and made persistent.${NC}"

# --- 8. Guided Manual First Run & Systemd Setup ---
echo -e "${BLUE}[8/8] Final Manual Setup & Optional Service Installation...${NC}"
echo -e "${YELLOW}==================== ATTENTION REQUIRED ====================${NC}"
echo "The next step is to run the server ONCE to create the admin password."
echo "I will run the command for you. You will see the server startup sequence."
echo "When you see the prompt, type your admin password and press Enter. Confirm it."
echo "After the server fully starts (log says '*** SERVER STARTED ****'), please stop it with Ctrl+C."
echo -e "${YELLOW}Press Enter when you are ready to begin...${NC}"
read

sudo -u "$PZ_USER" bash -c "cd $PZ_SERVER_DIR && ./start-server.sh"

echo -e "${GREEN}Initial password setup is assumed to be complete.${NC}"
read -p "Do you want to set up Project Zomboid with systemd for auto-start? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating systemd service and socket files..."
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
    echo -e "${GREEN}Service started successfully! Use 'systemctl status zomboid' to check.${NC}"
else
    echo -e "${YELLOW}Setup complete. Run server manually when needed.${NC}"
fi

echo -e "${GREEN}All done. APE TOGETHER STRONK!${NC}"
