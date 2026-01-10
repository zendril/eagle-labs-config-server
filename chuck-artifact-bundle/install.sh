#!/bin/bash
set -e

echo "Activating feature 'chuck'..."

# Install Chuck Tool
echo "Installing chuck..."
cp "$(dirname "$0")/chuck.sh" /usr/local/bin/chuck
chmod +x /usr/local/bin/chuck

# Install Governance Script
echo "Installing governance script..."
cp "$(dirname "$0")/check-version.sh" /usr/local/bin/check-chuck
chmod +x /usr/local/bin/check-chuck

# Install Entrypoint Script
echo "Installing entrypoint script..."
cp "$(dirname "$0")/entrypoint.sh" /usr/local/bin/entrypoint-chuck
chmod +x /usr/local/bin/entrypoint-chuck

# Install Compliance Notifier
echo "Installing compliance notifier..."
cp "$(dirname "$0")/compliance-notifier.sh" /usr/local/bin/compliance-notifier-chuck
chmod +x /usr/local/bin/compliance-notifier-chuck


# Cleanup legacy trap files if they exist (from previous installs)
rm -f /etc/profile.d/99-chuck-block.sh

# Create a placeholder directory for the mount and ensure it's writable by all users
mkdir -p /usr/local/share/chuck-cache
chmod 777 /usr/local/share/chuck-cache

# Ensure global state directory exists
mkdir -p /etc/eagle-labs
chmod 755 /etc/eagle-labs

echo "Chuck installed!"
