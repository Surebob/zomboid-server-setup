#!/bin/bash
#
# ================================================================= #
#               PROJECT ZOMBOID - APE TOGETHER STRONK               #
#                  MASTER SETUP SCRIPT (Ubuntu)                     #
# ================================================================= #
# This script automates the complete setup for a Project Zomboid    #
# dedicated server on a fresh Ubuntu instance.                      #
# It includes:                                                      #
#   - System updates and dependencies                               #
#   - Firewall configuration (iptables)                             #
#   - A dedicated, non-root user for security                       #
#   - SteamCMD and Project Zomboid server installation              #
# ================================================================= #

# --- Script Configuration ---
# You can change these variables if you want.
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
  echo -e "${YELLOW}Please run this script with sudo: sudo ./setup-zomboid.sh${NC}"
  exit 1
fi

echo -e "${BLUE}--- Starting Project Zomboid Server Setup ---${NC}"

# --- 1. System Preparation ---
echo -e "${BLUE}[1/6] Preparing system and installing dependencies...${NC}"
apt-get update
apt-get install -y software-properties-common

# Add multiverse for steamcmd and i386 for 32-bit libraries
add-apt-repository multiverse
dpkg --add-architecture i386
apt-get update
echo -e "${GREEN}System preparation complete.${NC}"

# --- 2. SteamCMD Installation ---
echo -e "${BLUE}[2/6] Installing SteamCMD...${NC}"
# Pre-accept the Steam license to avoid interactive prompts
echo "steam steam/question select \"I AGREE\"" | debconf-set-selections
echo "steam steam/license note ''" | debconf-set-selections
apt-get install -y steamcmd

# --- 3. Create Dedicated User & Directories ---
echo -e "${BLUE}[3/6] Creating dedicated user ('$PZ_USER') and server directory...${NC}"
useradd -m -s /bin/bash "$PZ_USER"
echo "$PZ_USER:$PZ_PASSWORD" | chpasswd
adduser "$PZ_USER" sudo

# Create server directory and set permissions
mkdir -p "$PZ_SERVER_DIR"
chown "$PZ_USER":"$PZ_USER" "$PZ_SERVER_DIR"
echo -e "${GREEN}User and directory created successfully.${NC}"

# --- 4. Download Project Zomboid Server ---
echo -e "${BLUE}[4/6] Downloading Project Zomboid server files as user '$PZ_USER'...${NC}"
# Create the update script
cat > "/home/$PZ_USER/update_zomboid.txt" <<'EOL'
// update_zomboid.txt
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir /opt/pzserver/
login anonymous
app_update 380870 validate
quit
EOL

# Set ownership of the script
chown "$PZ_USER":"$PZ_USER" "/home/$PZ_USER/update_zomboid.txt"

# Run steamcmd as the dedicated user
sudo -u "$PZ_USER" /usr/games/steamcmd +runscript "/home/$PZ_USER/update_zomboid.txt"
echo -e "${GREEN}Project Zomboid server downloaded successfully.${NC}"

# --- 5. Configure OS Firewall (iptables) ---
echo -e "${BLUE}[5/6] Configuring OS-level firewall (iptables)...${NC}"
# Insert rules at the top of the INPUT chain to allow game traffic
iptables -I INPUT 5 -p udp --dport 16261 -j ACCEPT
iptables -I INPUT 6 -p udp --dport 8766 -j ACCEPT
iptables -I INPUT 7 -p udp --dport 16262:16272 -j ACCEPT

# Install persistence package to save firewall rules across reboots
# Pre-answer the interactive prompts
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
apt-get install -y iptables-persistent

# Just to be safe, save the rules again
netfilter-persistent save
echo -e "${GREEN}iptables rules applied and made persistent.${NC}"

# --- 6. Final Manual Steps ---
echo -e "${BLUE}[6/6] Setup Complete! Next steps are manual.${NC}"
echo -e "${YELLOW}==================== ATTENTION REQUIRED ====================${NC}"
echo -e "The server needs to be run ONCE manually to set your admin password."
echo -e "Follow these steps:"
echo ""
echo -e "1. Switch to the pzuser: ${GREEN}sudo -u $PZ_USER -i${NC}"
echo -e "2. Navigate to the server directory: ${GREEN}cd $PZ_SERVER_DIR${NC}"
echo -e "3. Start the server: ${GREEN}bash start-server.sh${NC}"
echo -e "4. When prompted, enter and confirm a new password for the 'admin' user."
echo -e "5. Once the server says '*** SERVER STARTED ****', you can stop it with ${GREEN}Ctrl+C${NC}."
echo ""
echo -e "After setting the password, you can run the ${GREEN}systemd-setup.sh${NC} script to manage the server as a service."
echo -e "${YELLOW}============================================================${NC}"
