#!/bin/bash
# =============================================================================
# Open-WebUI Manager Script
# =============================================================================
#
# A clean and robust management script for Open-WebUI.
#
# Features:
#   • Starts Open-WebUI inside a detached screen session
#   • Automatically detects and uses a free port if 3000 is occupied
#   • Proper health check: waits until the web UI is fully loaded
#     (port listening + valid HTTP/HTML response)
#   • Opens Firefox automatically when the server is ready
#   • Option to stop or restart if server is already running
#   • Clean, user-friendly console output
#
# Usage:
#   ./owui                  → Start (or manage) Open-WebUI
#   ./owui                  → If running: offers stop/restart
#
# Requirements:
#   • Open-WebUI installed in ~/.open-webui
#   • venv environment with open-webui package
#   • screen, curl, ss, firefox installed
#
# Author: Assisted by Grok
# Version: 0.3
# Last Updated: May 2026
# =============================================================================

# === Global Configuration ===
DCRoot=~/.open-webui
ScreenSessionName="open-webui_server"
WUIPort=3000
Browser="firefox_opt"
MAX_WAIT=45                    # Maximum wait time in seconds

# === Helper Functions ===

check_for_running_open_webui_server() {
    screen -ls | grep -q "$ScreenSessionName"
}

is_port_listening() {
    ss -tuln | grep -q ":$1 "
}

http_healthcheck() {
    # Checks if we get a real HTTP response with HTML content
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

    echo -e "\r❌ Timeout: Server did not respond in time.               "
    return 1
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
    read -p "Do you want to [s]top or [r]estart the server? (Enter = stop) " choice
    choice=${choice:-s}
    
    case "$choice" in
        [Rr]*)
            stop_server
            sleep 2
            find_free_port
            start_server
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
