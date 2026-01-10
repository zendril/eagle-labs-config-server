#!/bin/bash

# Chuck Tool
# Usage: chuck {speak|version|home}

log_and_print() {
    local msg="$1"
    echo "$msg"
    
    # Use CHUCK_CACHE_DIR if set, otherwise default to user home
    local cache_dir="${CHUCK_CACHE_DIR:-$HOME/.chuck-cache}"
    
    # Log to cache if directory exists
    if [ -d "$cache_dir" ]; then
        echo "$msg" > "$cache_dir/chuck-$(date +%s).txt"
    fi
}

case "$1" in
    speak)
        log_and_print "howdy"
        ;;
    version)
        log_and_print "1"
        ;;
    home)
        log_and_print "not implemented"
        ;;
    *)
        echo "Usage: chuck {speak|version|home}"
        exit 1
        ;;
esac
