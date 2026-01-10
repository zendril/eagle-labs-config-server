#!/bin/bash
set -e

# Eagle Labs Reggie Entrypoint
# Wraps container startup to enforce governance.

# Ensure directory exists for state tracking
# (Ideally installed by install.sh, but good for robustness)
mkdir -p /etc/eagle-labs

# 1. Run the Governance Check
# We suppress output if successful.
set +e
/usr/local/bin/check-chuck --quiet
CHECK_STATUS=$?
set -e

# Cleanup old notices
rm -f /etc/eagle-labs/chuck-notice-*

# Read the days calculated by check-reggie
if [ -f "/etc/eagle-labs/chuck-days" ]; then
    DAYS=$(cat "/etc/eagle-labs/chuck-days")
else
    DAYS=0
fi

# Read the release date
if [ -f "/etc/eagle-labs/chuck-date" ]; then
    R_DATE=$(cat "/etc/eagle-labs/chuck-date")
else
    R_DATE="Unknown"
fi

TOOL_NAME="Chuck"

if [ $CHECK_STATUS -eq 0 ]; then
    # COMPLIANT: Check for warning windows
    if [ "$DAYS" -ge 30 ]; then
        # 30-44 Days: Urgent Warning (CRITICAL visual)
        printf "═[ \033[38;5;208m!  CRITICAL \033[0m]═══════════════════════════════════════════════════════════════════\n· %s updated %s (CRITICAL)\n· Your version is %s days out of compliance\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$R_DATE" "$DAYS" > /etc/eagle-labs/chuck-notice-30-44
    elif [ "$DAYS" -ge 15 ]; then
        # 15-29 Days: Warning
        printf "═[ \033[33m⚠  WARNING \033[0m]═══════════════════════════════════════════════════════════════════\n· %s updated %s (WARNING)\n· Your version is %s days out of compliance\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$R_DATE" "$DAYS" > /etc/eagle-labs/chuck-notice-15-29
    else
        # 0-14 Days: Info
        printf "═[ \033[34mℹ  INFO \033[0m]═══════════════════════════════════════════════════════════════════════\n· %s updated %s (INFO)\n· Your version is %s days out of compliance\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$R_DATE" "$DAYS" > /etc/eagle-labs/chuck-notice-0-14
    fi
    
    exec "$@"
elif [ $CHECK_STATUS -eq 2 ]; then
    # WARNING: Connection Failed to Policy Server
    # Treat as INFO/WARN but do not block.
    printf "═[ \033[33m⚠  WARNING \033[0m]═══════════════════════════════════════════════════════════════════\n· %s (WARNING)\n· Unable to reach policy server (connection failed)\n· Governance check skipped\n" "$TOOL_NAME" > /etc/eagle-labs/chuck-notice-connection

    exec "$@"
else
    # NON-COMPLIANT
    # The check-reggie script already printed errors to stdout if not quiet, but we ran quiet.
    
    TOMBSTONE="/etc/eagle-labs/chuck-removed.msg"
    
    echo "================================================================="
    echo "    CONTAINER STARTUP WARNED BY EAGLE LABS GOVERNANCE"
    echo "    Feature 'Chuck' has been uninstalled due to policy violation."
    echo "================================================================="
    
    # Create valid tombstone content (DISABLED visual)
    printf "═[ \033[31m☠  DISABLED \033[0m]══════════════════════════════════════════════════════════════════\n· %s updated %s (DISABLED)\n· Your version is %s days out of compliance and has been DISABLED\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$R_DATE" "$DAYS" > "$TOMBSTONE"
    
    # Ensure it is readable
    chmod 644 "$TOMBSTONE"

    # SCORCHED EARTH: Remove the tool
    rm -f "/usr/local/bin/chuck"
    
    # Resume startup
    exec "$@"
fi
