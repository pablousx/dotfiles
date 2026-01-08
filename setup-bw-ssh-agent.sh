#!/bin/bash
# This code is licensed under MIT license https://choosealicense.com/licenses/mit/
#
# Note: I have only tested lightly and this seems to work. I won't take the blame if this makes your
# machine catch fire.
#
# Thanks to Aaron and the original work discussed here:
# https://www.rebelpeon.com/bitwarden-ssh-agent-on-wsl2/
#
# If you want to run this script as is you can:
# wget https://gist.githubusercontent.com/jkwmoore/ce9eab106fe378709f447c843b0090e4/raw/setup-bw-ssh-agent.sh && bash setup-bw-ssh-agent.sh

echo "Installing npiperelay..."
/mnt/c/WINDOWS/system32/cmd.exe /c "winget install --id=albertony.npiperelay  -e"

echo "Installing socat..."
sudo apt-get update
sudo apt-get install -y socat

echo "Creating SSH agent bridge script..."

mkdir -p ~/scripts

cat << 'EOF' > ~/scripts/agent-bridge.sh
#!/bin/bash
USERNAME=$(/mnt/c/WINDOWS/system32/cmd.exe /c echo %USERNAME% 2>/dev/null | tr -d "\r\n")

# Ensure ~/.ssh directory exists with correct permissions
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -m 700 "$HOME/.ssh"
fi

export SSH_AUTH_SOCK=$HOME/.ssh/agent.sock
ss -a | grep -q $SSH_AUTH_SOCK
if [ $? -ne 0 ]; then
    rm -f $SSH_AUTH_SOCK
    ( setsid socat UNIX-LISTEN:$SSH_AUTH_SOCK,fork EXEC:"/mnt/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork & ) >/dev/null 2>&1
fi
EOF

chmod +x ~/scripts/agent-bridge.sh

echo "Ensuring bridge script is sourced in .bashrc..."

BASHRC=~/.bashrc
BRIDGE_SOURCE="source ~/scripts/agent-bridge.sh"

if ! grep -Fxq "$BRIDGE_SOURCE" "$BASHRC"; then
    echo "$BRIDGE_SOURCE" >> "$BASHRC"
    echo "Added agent bridge script to .bashrc"
else
    echo "Bridge script already sourced in .bashrc"
fi

echo "Setup complete! Restart your shell or run:"
echo "source ~/scripts/agent-bridge.sh"