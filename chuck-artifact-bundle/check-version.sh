#!/bin/bash

# Eagle Labs Governance Check for Reggie
# Usage: check-reggie [--quiet]

# Check for Tombstone (Feature Uninstalled)
TOMBSTONE="/etc/eagle-labs/chuck-removed.msg"
if [ -f "$TOMBSTONE" ]; then
    cat "$TOMBSTONE"
    exit 1
fi

# Check for quiet flag
QUIET_MODE="false"
if [ "$1" = "--quiet" ]; then
    QUIET_MODE="true"
fi

# Use host.docker.internal to reach the host machine from within the container
# or use POLICY_HOST env var if set (e.g. by Docker Compose)
POLICY_HOST="${POLICY_HOST:-http://host.docker.internal:3000}"
POLICY_URL="${POLICY_HOST}/policy/chuck/latest"
if [ "$QUIET_MODE" = "false" ]; then
    echo "Fetching policy from $POLICY_URL..."
fi

# Telemetry Collection
collect_telemetry() {
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=${USER:-"unknown"}
    local host=$(hostname)
    local mid="unknown"
    [ -f /etc/machine-id ] && mid=$(cat /etc/machine-id)
    local os="unknown"
    [ -f /etc/os-release ] && os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    local wsl=${WSL_DISTRO_NAME:-"none"}
    local ci=${CI:-"false"}
    
    # Escape quotes for JSON safety (basic)
    os=$(echo "$os" | sed 's/"/\\"/g')
    
    echo "{
        \"feature\": \"chuck\",
        \"timestamp\": \"$ts\",
        \"username\": \"$user\",
        \"hostname\": \"$host\",
        \"machine_id\": \"$mid\",
        \"os_pretty_name\": \"$os\",
        \"wsl_distro\": \"$wsl\",
        \"ci_env\": \"$ci\",
        \"client_version\": \"$CHUCK_VER\"
    }"
}

# Determine Chuck Version for Telemetry
CHUCK_VER="unknown"
if command -v chuck >/dev/null 2>&1; then
    CHUCK_VER=$(chuck version)
fi

# Build Payload
TELEMETRY_JSON=$(collect_telemetry)

if [ "$QUIET_MODE" = "false" ]; then
    echo "Sending Telemetry..."
    echo "$TELEMETRY_JSON"
fi

# Fetch policy (POST with Telemetry)
POLICY_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$TELEMETRY_JSON" --max-time 2 "$POLICY_URL")

if [ -z "$POLICY_RESPONSE" ]; then
    echo "Error: Could not fetch policy from $POLICY_URL"
    exit 2
fi

# Extract version and release date using basic grep/cut
LATEST_ALLOWED_VERSION=$(echo "$POLICY_RESPONSE" | grep -o '"latest_version":"[^"]*"' | cut -d'"' -f4)
RELEASE_DATE=$(echo "$POLICY_RESPONSE" | grep -o '"release_date":"[^"]*"' | cut -d'"' -f4)
GRACE_PERIOD_DAYS=30 

if [ "$QUIET_MODE" = "false" ]; then
    echo "Policy: Latest Allowed Version: $LATEST_ALLOWED_VERSION"
    echo "Policy: Release Date: $RELEASE_DATE"
fi

# Function to calculate days difference
get_days_diff() {
    local d1=$(date -d "$1" +%s)
    local d2=$(date -d "$2" +%s)
    echo $(( (d2 - d1) / 86400 ))
}

# Check current chuck version
if command -v chuck >/dev/null 2>&1; then
    CHUCK_VER=$(chuck version)
    if [ "$QUIET_MODE" = "false" ]; then
        echo "Detected Chuck Version: $CHUCK_VER"
    fi
    
    if [ "$CHUCK_VER" = "$LATEST_ALLOWED_VERSION" ]; then
        if [ "$QUIET_MODE" = "false" ]; then
            echo "Status: COMPLIANT"
        fi
        exit 0
    else
        if [ "$QUIET_MODE" = "false" ]; then
            echo "Status: NON-COMPLIANT (Expected $LATEST_ALLOWED_VERSION)"
        fi
        
        # Calculate how old the release is
        CURRENT_DATE=$(date +%Y-%m-%d)
        DAYS_SINCE_RELEASE=$(get_days_diff "$RELEASE_DATE" "$CURRENT_DATE")

        # Write state for entrypoint/notifier
        mkdir -p /etc/eagle-labs
        echo "$DAYS_SINCE_RELEASE" > /etc/eagle-labs/chuck-days
        echo "$RELEASE_DATE" > /etc/eagle-labs/chuck-date
        chmod 644 /etc/eagle-labs/chuck-days /etc/eagle-labs/chuck-date
        
        if [ "$QUIET_MODE" = "false" ]; then
            echo "Days since release: $DAYS_SINCE_RELEASE"
        fi

        if [ "$DAYS_SINCE_RELEASE" -lt 15 ]; then
             # < 15 Days: Silent / Log Only
            [ "$QUIET_MODE" = "false" ] && echo "Grace Period: Update available but not yet enforced."
            exit 0
        elif [ "$DAYS_SINCE_RELEASE" -lt 30 ]; then
             # 15-30 Days: Gentle Warning
            [ "$QUIET_MODE" = "false" ] && echo "WARNING: Your version of Chuck is outdated. Please update soon."
            exit 0
        elif [ "$DAYS_SINCE_RELEASE" -ge 30 ] && [ "$DAYS_SINCE_RELEASE" -lt 45 ]; then
            [ "$QUIET_MODE" = "false" ] && echo "URGENT: You are nearing the mandatory update deadline."
            exit 0
        else
             # > 45 Days: Hard Block
            [ "$QUIET_MODE" = "false" ] && echo "CRITICAL: Mandatory update required. Access Denied."
            exit 1
        fi
    fi
else
    echo "Chuck tool not found!"
    exit 1
fi
