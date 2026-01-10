#!/bin/bash
# Eagle Labs Compliance Notifier
# Checks for signals left by entrypoint and notifies/blocks the user accordingly.
# This script is intended to run as a postStartCommand or similar lifecycle hook.

# 1. Check for Tombstone (Post-mortem)
if [ -f "/etc/eagle-labs/chuck-removed.msg" ]; then
    echo ""
    cat "/etc/eagle-labs/chuck-removed.msg"
    echo ""
fi

# 2. Check for Urgent Warning (30-44 Days)
if [ -f "/etc/eagle-labs/chuck-notice-30-44" ]; then
    echo ""
    cat "/etc/eagle-labs/chuck-notice-30-44"
    echo ""
    echo "ACKNOWLEDGE: Press ENTER to confirm you have seen this warning..."
    # Force interaction to ensure they see it
    read -r
fi

# 3. Check for Warnings (15-29 Days)
if [ -f "/etc/eagle-labs/chuck-notice-15-29" ]; then
    echo ""
    cat "/etc/eagle-labs/chuck-notice-15-29"
    echo ""
fi

# 4. Check for Info (0-14 Days)
if [ -f "/etc/eagle-labs/chuck-notice-0-14" ]; then
    # We can keep this silent or verbose. The user asked to "just print out...".
    cat "/etc/eagle-labs/chuck-notice-0-14"
    echo ""
fi

# 5. Check for Connection Warning
if [ -f "/etc/eagle-labs/chuck-notice-connection" ]; then
    cat "/etc/eagle-labs/chuck-notice-connection"
    echo ""
fi
