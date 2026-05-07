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
#   • CUDA Restart option ( CUDA Stack fails sometime after wakeup from suspend)
#   • Open-Webui update funktion available
#   • Runs Open-WebUI inside a named screen session
#   • Automatic free port detection
#   • Robust readiness check (HTTP + HTML content)
#   • Clean progress indication
#   • Stop / Restart / Quit options
#   • On timeout: attaches to screen session for debugging
#
# Author: speefak
# Version: 0.5
# Date: May 2026
# =============================================================================

# === Global Configuration ===
DCRoot="$HOME/.open-webui"
ScreenSessionName="open-webui_server"
WUIPort=3000
Browser="firefox_opt"
MAX_WAIT=20

# ===================== OPTIONS =====================

show_help() {
cat <<EOF
Open-WebUI Manager

Usage:
  $(basename "$0") [OPTION]

Options:
  -u    Update Open-WebUI
  -r    Restart CUDA modules
  -h    Show this help

No option:
  Start Open-WebUI normally
EOF
}

update_open_webui() {
    cd "$DCRoot" || {
        echo "❌ Directory $DCRoot not found!"
        exit 1
    }

    echo "🔄 Updating Open-WebUI..."
    source "$DCRoot/venv/bin/activate"
    pip install --upgrade pip
    pip install --upgrade open-webui
    deactivate
    echo "✅ Update complete."
}

CUDA_restart() {
    echo "🔁 Restarting NVIDIA/CUDA stack..."

    sudo rmmod nvidia_uvm nvidia_drm nvidia_modeset nvidia 2>/dev/null
    sudo modprobe nvidia
    sudo modprobe nvidia_uvm
    sudo modprobe nvidia_drm
    sudo modprobe nvidia_modeset
    sudo systemctl restart nvidia-persistenced

    echo "✅ CUDA stack restarted."
}

handle_options() {
    while getopts ":urh" opt; do
        case "$opt" in
            u)
                update_open_webui
                exit 0
                ;;
            r)
                CUDA_restart
                exit 0
                ;;
            h)
                show_help
                exit 0
                ;;
            \?)
                echo "❌ Unknown option: -$OPTARG"
                show_help
                exit 1
                ;;
        esac
    done
}

# ===================== HELPERS =====================

check_for_running_open_webui_server() {
    screen -ls | grep -q "$ScreenSessionName"
}

is_port_listening() {
    ss -tuln | grep -q ":$1 "
}

http_healthcheck() {
    curl -s --max-time 3 "http://localhost:$1" | grep -qi "open-webui\|html\|webui"
}

wait_for_server_ready() {
    local port=$1
    local waited=0

    echo -n "⏳ Waiting for Open-WebUI"

    while [ $waited -lt $MAX_WAIT ]; do
        if is_port_listening "$port" && http_healthcheck "$port"; then
            echo -e "\r✅ Open-WebUI is ready!        "
            return 0
        fi

        sleep 2
        ((waited+=2))
        echo -n "."
    done

    echo -e "\r⚠️ Timeout reached."

    if screen -ls | grep -q "$ScreenSessionName"; then
        echo "🔗 Attaching to session..."
        screen -r "$ScreenSessionName"
    else
        echo "❌ Server failed to start."
    fi

    exit 1
}

find_free_port() {
    local port=$WUIPort

    while ss -tuln | grep -q ":$port "; do
        echo "⚠️ Port $port in use"
        ((port++))
        [ $port -gt 65535 ] && {
            echo "❌ No free port found"
            exit 1
        }
    done

    WUIPort=$port
}

start_server() {
    echo "🚀 Starting Open-WebUI..."

    cd "$DCRoot" || {
        echo "❌ Directory not found"
        exit 1
    }

    screen -dmS "$ScreenSessionName" bash -c "
        source venv/bin/activate
        open-webui serve --host 0.0.0.0 --port $WUIPort
    "

    sleep 2
    wait_for_server_ready "$WUIPort"

    echo "🌐 Opening browser..."
    $Browser "http://localhost:$WUIPort" &>/dev/null &
}

stop_server() {
    echo "🛑 Stopping Open-WebUI..."
    screen -S "$ScreenSessionName" -X quit 2>/dev/null
    sleep 1
    echo "✅ Stopped."
}

# ===================== MAIN =====================

handle_options "$@"

echo "=== Open-WebUI Manager ==="

if check_for_running_open_webui_server; then
    echo "✅ Already running"
    echo
    read -n 1 -p "Stop / Restart / Quit? [s/r/q] (default s): " choice
    echo 
    choice=${choice:-s}

    case "$choice" in
        r|R)
            stop_server
            sleep 2
            find_free_port
            start_server
            ;;
        q|Q)
            echo "👋 Exit"
            exit 0
            ;;
        *)
            stop_server
            ;;
    esac
else
    echo "ℹ️ Not running"
    find_free_port
    start_server
fi
