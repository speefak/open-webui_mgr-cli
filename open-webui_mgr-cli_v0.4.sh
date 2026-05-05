#!/bin/bash
# =============================================================================
# Open-WebUI Manager
# =============================================================================
#
# A clean, reliable and user-friendly management script for Open-WebUI.
#
# This script launches Open-WebUI in a detached screen session, performs
# a proper health check (port + actual web content), and automatically
# opens the browser when the UI is fully ready.
#
# Features:
#   • Runs Open-WebUI inside a named screen session
#   • Automatic free port detection
#   • Robust readiness check (HTTP + HTML content)
#   • Clean progress indication
#   • Stop / Restart / Quit options
#   • On timeout: attaches to screen session for debugging
#
# Author: speefak
# Version: 0.4
# Date: May 2026
# =============================================================================

# === Global Configuration ===
DCRoot=~/.open-webui
ScreenSessionName="open-webui_server"
WUIPort=3000
Browser="firefox_opt"
MAX_WAIT=20                    # wait time for WUI initiating in seconds

# === Helper Functions ===

check_for_running_open_webui_server() {
    screen -ls | grep -q "$ScreenSessionName"
}

is_port_listening() {
    ss -tuln | grep -q ":$1 "
}

http_healthcheck() {
    curl -s --max-time 3 "http://localhost:$1" | grep -qi "html\|open-webui\|webui" 2>/dev/null
}

wait_for_server_ready() {
    local port=$1
    local waited=0

    echo -n "⏳ Waiting for Open-WebUI to be fully ready"

    while [ $waited -lt $MAX_WAIT ]; do
        if is_port_listening "$port" && http_healthcheck "$port"; then
            echo -e "\r✅ Open-WebUI is ready!                              "
            return 0
        fi
        
        sleep 2
        ((waited+=2))
        echo -n "."
    done

    echo -e "\r⚠️  Timeout: Server did not respond in time.               "
    echo "   Attaching to screen session for debugging..."
    
    # Try to attach to screen session
    if screen -ls | grep -q "$ScreenSessionName"; then
        echo "🔗 Attaching to screen session (press Ctrl+A then D to detach)..."
        sleep 1
        screen -r "$ScreenSessionName"
        exit 1
    else
        echo "❌ Error: Screen session '$ScreenSessionName' not found!"
        echo "   Server failed to start properly."
        exit 1
    fi
}

find_free_port() {
    local port=$WUIPort
    while ss -tuln | grep -q ":$port "; do
        echo "⚠️  Port $port is in use, trying $((port+1))"
        ((port++))
        [ $port -gt 65535 ] && { echo "❌ No free port found!"; exit 1; }
    done
    WUIPort=$port
}

start_server() {
    echo "🚀 Starting Open-WebUI in screen session '$ScreenSessionName'..."
    cd "$DCRoot" || { echo "❌ Directory $DCRoot not found!"; exit 1; }
    
    screen -dmS "$ScreenSessionName" bash -c "
        source venv/bin/activate
        open-webui serve --port $WUIPort --host 0.0.0.0
    "

    sleep 2
    wait_for_server_ready "$WUIPort"
    
    echo "🌐 Opening browser..."
    $Browser "http://localhost:$WUIPort" &>/dev/null &
}

stop_server() {
    echo "🛑 Stopping Open-WebUI..."
    screen -S "$ScreenSessionName" -X quit 2>/dev/null
    sleep 1.5
    echo "✅ Server stopped successfully."
}

# ====================== MAIN LOGIC ======================

echo "=== Open-WebUI Manager ==="

if check_for_running_open_webui_server; then
    echo "✅ Open-WebUI is already running."
    echo
    read -p "Do you want to [s]top, [r]estart or [q]uit? (Enter = stop) " choice
    choice=${choice:-s}
    
    case "$choice" in
        [Rr]*)
            stop_server
            sleep 2
            find_free_port
            start_server
            ;;
        [Qq]*)
            echo "👋 Quitting without changes."
            exit 0
            ;;
        *)
            stop_server
            ;;
    esac
else
    echo "Open-WebUI is not running."
    find_free_port
    start_server
fi
