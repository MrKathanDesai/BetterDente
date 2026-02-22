#!/bin/bash

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

echo "Installing BetterDente Privileged Helper Tool..."

APP_DIR="/Users/kathandesai/.gemini/antigravity/scratch/BetterDenteApp/BetterDente.app"
HELPER_BIN="$APP_DIR/Contents/Resources/BetterDenteHelper"

TARGET_BIN="/Library/PrivilegedHelperTools/com.kathandesai.BetterDenteHelper"
TARGET_PLIST="/Library/LaunchDaemons/com.kathandesai.BetterDenteHelper.plist"

if [ ! -d "$APP_DIR" ]; then
    echo "Error: BetterDente.app not found in the scratch directory."
    exit 1
fi

if [ ! -f "$HELPER_BIN" ]; then
    echo "Error: BetterDenteHelper not found in the App bundle."
    exit 1
fi

echo "Unloading existing daemon..."
launchctl bootout system "$TARGET_PLIST" 2>/dev/null

mkdir -p /Library/PrivilegedHelperTools

# Copy the binary
echo "Copying the helper binary to /Library/PrivilegedHelperTools..."
cp "$HELPER_BIN" "$TARGET_BIN"
chown root:wheel "$TARGET_BIN"
chmod 755 "$TARGET_BIN"

# Create the plist
echo "Generating the LaunchDaemon plist..."
cat << EOF > "$TARGET_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kathandesai.BetterDenteHelper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/com.kathandesai.BetterDenteHelper</string>
    </array>
    <key>MachServices</key>
    <dict>
        <key>com.kathandesai.BetterDenteHelper</key>
        <true/>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Fix permissions for the LaunchDaemon
chown root:wheel "$TARGET_PLIST"
chmod 644 "$TARGET_PLIST"

# Load the daemon
echo "Loading daemon into launchd system domain..."
launchctl bootstrap system "$TARGET_PLIST"

echo "Installation complete! The background helper should now be active."
