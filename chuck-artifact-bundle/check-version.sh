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

# Telemetry Collection (Consolidated)
collect_telemetry() {
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=${USER:-"unknown"}
    local host=$(hostname)
    local mid="unknown"
    [ -f /etc/machine-id ] && mid=$(cat /etc/machine-id | tr -d '\n')
    local os_pretty="unknown"
    [ -f /etc/os-release ] && os_pretty=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    local wsl=${WSL_DISTRO_NAME:-"none"}
    local ci=${CI:-"false"}

    # Collect full OS info from /etc/os-release
    local os_full=""
    [ -f /etc/os-release ] && os_full=$(cat /etc/os-release)

    # Collect feature markers (installed features with versions)
    local markers_json="{}"
    local markers_dir="/usr/local/share/eagle-labs/markers"
    if [ -d "$markers_dir" ] && [ -n "$(find "$markers_dir" -type f 2>/dev/null)" ]; then
        markers_json=$(jq -n "{}" 2>/dev/null || echo "{}")
        if command -v jq >/dev/null 2>&1; then
            # Use jq to safely build markers object
            for m in "$markers_dir"/*; do
                if [ -f "$m" ]; then
                    local marker_name=$(basename "$m")
                    local marker_version=$(cat "$m" | tr -d '\n')
                    markers_json=$(echo "$markers_json" | jq --arg name "$marker_name" --arg version "$marker_version" '. + {($name): $version}')
                fi
            done
        fi
    fi

    # Collect devcontainer.json config
    local config=""
    local project_name="Unknown"
    local config_file=$(find /workspaces -name "devcontainer.json" -type f 2>/dev/null | head -1)
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        config=$(cat "$config_file")
        # Extract project name from config
        project_name=$(grep -o '"name"\s*:\s*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4)
        [ -z "$project_name" ] && project_name="Unknown"
    fi

    # Collect bundle version (NEW)
    local bundle_version="unknown"
    if [ -f "/usr/local/share/eagle-labs/chuck-bundle-version" ]; then
        bundle_version=$(cat /usr/local/share/eagle-labs/chuck-bundle-version | tr -d '\n')
    fi

    # Use jq to build the JSON if available (proper escaping), otherwise use printf with proper escaping
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg feature "chuck" \
            --arg timestamp "$ts" \
            --arg username "$user" \
            --arg hostname "$host" \
            --arg machine_id "$mid" \
            --arg os_pretty_name "$os_pretty" \
            --arg wsl_distro "$wsl" \
            --arg ci_env "$ci" \
            --arg client_version "$CHUCK_VER" \
            --arg bundle_version "$bundle_version" \
            --arg sessionId "$host" \
            --arg os "$os_full" \
            --arg config "$config" \
            --arg projectName "$project_name" \
            --argjson markers "$markers_json" \
            '{
                feature: $feature,
                timestamp: $timestamp,
                username: $username,
                hostname: $hostname,
                machine_id: $machine_id,
                os_pretty_name: $os_pretty_name,
                wsl_distro: $wsl_distro,
                ci_env: $ci_env,
                client_version: $client_version,
                bundle_version: $bundle_version,
                sessionId: $sessionId,
                os: $os,
                markers: $markers,
                config: $config,
                projectName: $projectName
            }'
    else
        # Collect bundle version for fallback path
        bundle_version="unknown"
        if [ -f "/usr/local/share/eagle-labs/chuck-bundle-version" ]; then
            bundle_version=$(cat /usr/local/share/eagle-labs/chuck-bundle-version | tr -d '\n')
        fi

        # Fallback: escape quotes and newlines manually
        ts=$(printf '%s\n' "$ts" | sed 's/\\/\\\\/g; s/"/\\"/g')
        user=$(printf '%s\n' "$user" | sed 's/\\/\\\\/g; s/"/\\"/g')
        host=$(printf '%s\n' "$host" | sed 's/\\/\\\\/g; s/"/\\"/g')
        mid=$(printf '%s\n' "$mid" | sed 's/\\/\\\\/g; s/"/\\"/g')
        os_pretty=$(printf '%s\n' "$os_pretty" | sed 's/\\/\\\\/g; s/"/\\"/g')
        wsl=$(printf '%s\n' "$wsl" | sed 's/\\/\\\\/g; s/"/\\"/g')
        ci=$(printf '%s\n' "$ci" | sed 's/\\/\\\\/g; s/"/\\"/g')
        os_full=$(printf '%s\n' "$os_full" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
        config=$(printf '%s\n' "$config" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
        project_name=$(printf '%s\n' "$project_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
        bundle_version=$(printf '%s\n' "$bundle_version" | sed 's/\\/\\\\/g; s/"/\\"/g')

        echo "{
            \"feature\": \"chuck\",
            \"timestamp\": \"$ts\",
            \"username\": \"$user\",
            \"hostname\": \"$host\",
            \"machine_id\": \"$mid\",
            \"os_pretty_name\": \"$os_pretty\",
            \"wsl_distro\": \"$wsl\",
            \"ci_env\": \"$ci\",
            \"client_version\": \"$CHUCK_VER\",
            \"bundle_version\": \"$bundle_version\",
            \"sessionId\": \"$host\",
            \"os\": \"$os_full\",
            \"markers\": $markers_json,
            \"config\": \"$config\",
            \"projectName\": \"$project_name\"
        }"
    fi
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

# NEW: Check current bundle version (instead of chuck binary version)
CURRENT_BUNDLE_VERSION="unknown"
if [ -f "/usr/local/share/eagle-labs/chuck-bundle-version" ]; then
    CURRENT_BUNDLE_VERSION=$(cat /usr/local/share/eagle-labs/chuck-bundle-version | tr -d '\n')
fi

if [ "$QUIET_MODE" = "false" ]; then
    echo "Detected Bundle Version: $CURRENT_BUNDLE_VERSION"
fi

# Check if bundle version matches policy requirement
if [ "$CURRENT_BUNDLE_VERSION" = "$LATEST_ALLOWED_VERSION" ]; then
    if [ "$QUIET_MODE" = "false" ]; then
        echo "Status: COMPLIANT"
    fi
    exit 0
else
    if [ "$QUIET_MODE" = "false" ]; then
        echo "Status: NON-COMPLIANT (Expected $LATEST_ALLOWED_VERSION, Have $CURRENT_BUNDLE_VERSION)"
    fi

    # Calculate how old the release is
    CURRENT_DATE=$(date +%Y-%m-%d)
    DAYS_SINCE_RELEASE=$(get_days_diff "$RELEASE_DATE" "$CURRENT_DATE")
    TOOL_NAME="Chuck" # Used in notice messages

    # Create notice files directly based on the number of days.
    # The entrypoint will simply display any file that is found.
    mkdir -p /etc/eagle-labs
    rm -f /etc/eagle-labs/chuck-notice-* # Clean up old notices first

    if [ "$DAYS_SINCE_RELEASE" -ge 45 ]; then
        # > 45 Days: Hard Block
        if [ "$QUIET_MODE" = "false" ]; then
            echo "CRITICAL: Mandatory update required. Access Denied."
        fi
        # Create a tombstone message for the entrypoint to display
        printf "═[ \033[31m☠  DISABLED \033[0m]══════════════════════════════════════════════════════════════════\n· %s updated %s (DISABLED)\n· Your version is %s days out of compliance and has been disabled.\n· ⚡ Rebuild container to fix: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$RELEASE_DATE" "$DAYS_SINCE_RELEASE" > /etc/eagle-labs/chuck-removed.msg
        exit 1
    elif [ "$DAYS_SINCE_RELEASE" -ge 30 ]; then
        # 30-44 Days: Urgent Warning (CRITICAL visual)
        printf "═[ \033[38;5;208m!  CRITICAL \033[0m]═══════════════════════════════════════════════════════════════════\n· %s updated %s (CRITICAL)\n· Your version is %s days out of compliance\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$RELEASE_DATE" "$DAYS_SINCE_RELEASE" > /etc/eagle-labs/chuck-notice-30-44
    elif [ "$DAYS_SINCE_RELEASE" -ge 15 ]; then
        # 15-29 Days: Warning
        printf "═[ \033[33m⚠  WARNING \033[0m]═══════════════════════════════════════════════════════════════════\n· %s updated %s (WARNING)\n· Your version is %s days out of compliance\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$RELEASE_DATE" "$DAYS_SINCE_RELEASE" > /etc/eagle-labs/chuck-notice-15-29
    else
        # 0-14 Days: Info
        printf "═[ \033[34mℹ  INFO \033[0m]═══════════════════════════════════════════════════════════════════════\n· %s updated %s (INFO)\n· Your version is %s days out of compliance\n· ⚡ Update available, Rebuild with: 'Dev Containers: Rebuild Container'\n" "$TOOL_NAME" "$RELEASE_DATE" "$DAYS_SINCE_RELEASE" > /etc/eagle-labs/chuck-notice-0-14
    fi

    # Exit 0 to indicate success (no hard block)
    exit 0
fi
