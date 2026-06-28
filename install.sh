#!/usr/bin/env bash
# install.sh
# Ubuntu 22.04 LTS setup for SDN Federated Anomaly Detection Lab
# Purpose: This script installs everything needed for the lab:
# - Mininet from source (Python 3)
# - Ryu SDN controller
# - Tools: hping3, nmap, iperf3
# - Scapy (system-wide for Tool 3 raw socket access)
# Usage:
# chmod +x install.sh
# ./install.sh
# Last updated: June 14, 2026, 2130 hrs, I converted this from Ubuntu 20.04 to 22.04.

set -euo pipefail

# colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[install]${NC} $*"; }
warn() { echo -e "${YELLOW}[warning]${NC} $*"; }

# Step 1: System packages
info "Updating package lists..."
sudo apt-get update -qq

info "Installing system tools..."
sudo apt-get install -y \
    openvswitch-switch \
    hping3 \
    nmap \
    iperf3 \
    curl \
    git \
    python3-pip \
    python3-dev \
    python-is-python3 \
    build-essential \
    help2man \
    net-tools \
    --no-install-recommends

# Ensure Open vSwitch is running (required by Mininet)
sudo systemctl enable openvswitch-switch
sudo systemctl start  openvswitch-switch
info "[!] Open vSwitch running"

# Step 2: Path
# Set immediately after system packages so all subsequent pip installs
# are visible without warnings for the rest of the script.

if ! grep -q 'local/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    info "Added ~/.local/bin to PATH in ~/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# Step 3: Mininet from source
# The apt version of Mininet on Ubuntu 22.04 installs under Python 2.7.
# We need the source version for Python 3 compatibility.

info "Installing Mininet from source (Python 3)..."

# Clone into home directory to avoid conflicting with the sdn_mininet/ folder
if [ ! -d "$HOME/mininet-src" ]; then
    git clone https://github.com/mininet/mininet.git "$HOME/mininet-src"
fi

cd "$HOME/mininet-src"
git checkout 2.3.1b4

# Ubuntu 22.04 patch: newer kernel headers moved sched.h to linux/sched.h.
# Without this patch, mnexec fails to compile with:
# fatal error: sched.h: No such file or directory
sed -i 's/#include <sched.h>/#include <linux\/sched.h>/' mnexec.c 2>/dev/null || true
info "[!] mnexec kernel header patch applied"

# Remove old egg metadata that causes pip uninstall to fail on Ubuntu 22.04
sudo rm -rf /usr/local/lib/python3*/dist-packages/mininet* 2>/dev/null || true

# Install Python package
sudo python3 setup.py install

# Build and install mnexec binary
sudo make install

cd -   # return to previous directory

# Verify
if sudo python3 -c "import mininet" 2>/dev/null; then
    info "[!] Mininet (Python 3) installed successfully"
else
    warn "Mininet import failed. Check the source install above for errors."
fi

# Step 4: Ryu SDN framework
# Confirmed working combination for Ubuntu 22.04 / Python 3.10:
# eventlet 0.33.3 -> only version that clears the is_timeout error
# dnspython 2.8.0 -> 1.x uses collections.MutableMapping removed in 3.10
# greenlet 3.5.1 -> required by eventlet 0.33.3
# Three source patches are also required because Ryu is unmaintained
# and was written before Python 3.10 and eventlet 0.33.x were released.

info "Installing Ryu SDN framework..."
pip3 install --user \
    ryu \
    "eventlet==0.33.3" \
    "oslo.config" \
    "six" \
    "greenlet>=2.0" \
    "dnspython>=2.0.0"

# Patch 1: wsgi.py
# ALREADY_HANDLED was removed from eventlet.wsgi in 0.33.x.
# Ryu's wsgi.py imports it at module load time, causing an ImportError.
# Fix: define it as an empty bytes literal directly in the file.
info "Applying Ryu patch 1: wsgi.py ALREADY_HANDLED..."
WSGI=$(find ~/.local -name "wsgi.py" -path "*/ryu/app/*" 2>/dev/null || echo "")
if [ -n "$WSGI" ]; then
    sed -i 's/from eventlet.wsgi import ALREADY_HANDLED/ALREADY_HANDLED = b""/' "$WSGI"
    info "[!] wsgi.py patch applied"
else
    warn "wsgi.py not found — skipping patch 1"
fi

# Patch 2: timeout.py
# Python 3.10 made TimeoutError a built-in immutable type.
# eventlet tries to set is_timeout as a property on it, which raises:
# TypeError: cannot set 'is_timeout' attribute of immutable type 'TimeoutError'
# Fix: replace the offending line with a no-op pass statement.
info "Applying Ryu patch 2: timeout.py is_timeout..."
TIMEOUT=$(find ~/.local -name "timeout.py" -path "*/eventlet/*" 2>/dev/null || echo "")
if [ -n "$TIMEOUT" ]; then
    sed -i 's/base\.is_timeout = property(lambda _: True)/pass  # patched: is_timeout immutable in Python 3.10/' "$TIMEOUT"
    info "[!] timeout.py patch applied"
else
    warn "timeout.py not found — skipping patch 2"
fi

# Patch 3: collections.abc
# Python 3.10 removed legacy aliases like collections.MutableMapping.
# Ryu uses these aliases internally across multiple files.
# Fix: replace all occurrences with the correct collections.abc equivalents.
info "Applying Ryu patch 3: collections.abc compatibility..."
RYU_PATH=$(python3 -c "import ryu; import os; print(os.path.dirname(ryu.__file__))" 2>/dev/null || echo "")
if [ -n "$RYU_PATH" ]; then
    find "$RYU_PATH" -name "*.py" -exec \
        sed -i \
        's/collections\.MutableMapping/collections.abc.MutableMapping/g;
         s/collections\.Callable/collections.abc.Callable/g;
         s/collections\.Sequence/collections.abc.Sequence/g;
         s/collections\.Iterable/collections.abc.Iterable/g;
         s/collections\.Iterator/collections.abc.Iterator/g' {} \; 2>/dev/null || true
    info "[!] collections.abc patch applied to: $RYU_PATH"
else
    warn "Ryu installation path not found -> skipping patch 3"
fi

# Verify
if command -v ryu-manager &>/dev/null; then
    info "[!] ryu-manager found"
else
    warn "ryu-manager not in PATH. Run: source ~/.bashrc"
fi

# Step 5: Python dependencies
info "Installing Python dependencies..."
pip3 install --user -r requirements.txt

# Step 6: Scapy, system-wide for Tool 3
# Tool 3's injector opens raw sockets and must run with sudo.
# Packages installed with --user are not visible to root, so scapy
# must be installed system-wide using sudo pip3.
# Pinned to 2.5.0 to avoid Python 3.10 cryptography incompatibilities
# in newer versions (dcerpc, kerberos, smb optional module errors).

info "Installing scapy system-wide for Tool 3..."
sudo pip3 install "scapy==2.5.0"
info "[!] scapy==2.5.0 installed system-wide"

# Step 7: Quick Mininet self-test
info "Running Mininet connectivity self-test..."
sudo mn --test pingall 2>&1 | tail -5
sudo mn -c 2>/dev/null || true

# Display Results
echo ""
echo -e "${GREEN}-----------------------------------------------------${NC}"
echo -e "${GREEN}  --> Installation complete (now using Ubuntu 22.04)!${NC}"
echo -e "${GREEN}-----------------------------------------------------${NC}"
echo ""
echo "Next steps:"
echo ""
echo "In Terminal 1 -> Start Ryu controller:"
echo -e "${YELLOW}[bash->]${NC}  ryu-manager sdn_mininet/ryu_collector.py --observe-links"
echo ""
echo "In Terminal 2 -> Start Mininet topology:"
echo -e "${YELLOW}[bash->]${NC}  sudo python3 sdn_mininet/topology.py --time 120 --attack"
echo ""
echo "In Terminal 3 -> Watch flows accumulate:"
echo -e "${YELLOW}[bash->]${NC}  watch -n 5 wc -l data/live_client*.csv"
echo ""
echo "In Terminal 3 -> Run Tool 3 injector:"
echo -e "${YELLOW}[bash->]${NC}  sudo python3 sdn_mininet/injector.py --skip-sniff"
echo ""
echo "In Terminal 4 -> Verify Tool 3:"
echo -e "${YELLOW}[bash->]${NC}  sudo ovs-ofctl dump-flows s1 -O OpenFlow13"
echo ""
echo "[*] After collection -> train and detect:"
echo "python3 cli.py train --data data/live_client1.csv --out models/live_c1.pkl --client-id live_c1"
echo "python3 cli.py train --data data/live_client2.csv --out models/live_c2.pkl --client-id live_c2"
echo "python3 cli.py train --data data/live_client3.csv --out models/live_c3.pkl --client-id live_c3"
echo "python3 cli.py federate --models 'models/live_*.pkl' --out models/live_global.pkl"
echo "python3 cli.py detect --model models/live_global.pkl --data data/live_client2.csv --top-n 10"
echo ""
