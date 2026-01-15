#!/bin/bash
set -e

# Eagle Labs Reggie Entrypoint
# Wraps container startup to enforce governance.

# Ensure directory exists for state tracking
# (Ideally installed by install.sh, but good for robustness)
mkdir -p /etc/eagle-labs

# 1. Run the Governance Check and store the result.
# We suppress the check's output because the postStartCommand will handle notifications.
set +e
/usr/local/bin/check-chuck --quiet
CHECK_STATUS=$?
set -e

# 2. If the check resulted in a hard block (exit status 1), remove the tool.
if [ $CHECK_STATUS -eq 1 ]; then
    # The notifier will run via postStartCommand to explain *why* this happened.
    rm -f "/usr/local/bin/chuck"
fi

# 3. Resume container startup.
exec "$@"

