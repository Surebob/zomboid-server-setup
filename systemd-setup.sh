#!/bin/bash
#
# ================================================================= #
#          PROJECT ZOMBOID - SYSTEMD SERVICE SETUP SCRIPT           #
# ================================================================= #
# This script configures systemd to manage the Project Zomboid      #
# server. This allows for clean start/stop/restart and auto-start   #
# on server boot.                                                   #
#                                                                   #
# !! PREREQUISITE: You MUST have run the server manually once to !!  #
# !! set the admin password before running this script.           !!  #
# ================================================================= #

# --- Script Configuration ---
PZ_USER="pzuser"
PZ_SERVER_DIR="/opt/pzserver"

# --- Colors for Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Safety Check: Ensure script is run as root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run this script with sudo: sudo ./systemd-setup.sh${NC}"
  exit 1
fi

echo -e "${BLUE}--- Setting up systemd service for Project Zomboid ---${NC}"

# --- 1. Create the Zomboid Service File ---
echo -e "${BLUE}[1/3] Creating zomboid.service file...${NC}"
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
echo -e "${GREEN}zomboid.service created.${NC}"

# --- 2. Create the Zomboid Socket File ---
echo -e "${BLUE}[2/3] Creating zomboid.socket file...${NC}"
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
echo -e "${GREEN}zomboid.socket created.${NC}"

# --- 3. Reload Systemd and Start the Service ---
echo -e "${BLUE}[3/3] Reloading systemd and enabling the server...${NC}"
systemctl daemon-reload
systemctl enable --now zomboid.socket
echo -e "${GREEN}Service enabled and started!${NC}"

# --- Final Instructions ---
echo -e "${YELLOW}==================== SERVER MANAGEMENT ====================${NC}"
echo -e "Your server is now running as a service."
echo -e "Use these commands to manage it:"
echo ""
echo -e "Check Status: ${GREEN}systemctl status zomboid${NC}"
echo -e "Stop Server:  ${GREEN}systemctl stop zomboid${NC}"
echo -e "Start Server: ${GREEN}systemctl start zomboid.socket${NC} (or systemctl start zomboid)"
echo -e "Restart:      ${GREEN}systemctl restart zomboid${NC}"
echo ""
echo -e "View live logs with: ${GREEN}journalctl -u zomboid -f${NC}"
echo ""
echo -e "Send commands (e.g., 'help'): ${GREEN}echo \"help\" | sudo tee /opt/pzserver/zomboid.control${NC}"
echo -e "${YELLOW}=========================================================${NC}"
