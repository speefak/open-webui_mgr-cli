#!/bin/bash
# =============================================
# Open-WebUI Start/Stop Script v 0.1
# =============================================

# === Globale Variablen ===
DCRoot=~/.open-webui
ScreenSessionName="open-webui_server"
WUIPort=3000
Browser="firefox"

# === Hilfsfunktionen ===

check_for_running_open_webui_server() {
    if screen -ls | grep -q "$ScreenSessionName"; then
        return 0  # läuft
    else
        return 1  # läuft nicht
    fi
}

is_port_free() {
    local port=$1
    ! ss -tuln | grep -q ":$port " 2>/dev/null
}

wait_for_port() {
    local port=$1
    local timeout=30
    local count=0

    echo "⏳ Warte auf Port $port..."
    while ! is_port_free "$port" && [ $count -lt $timeout ]; do
        sleep 1
        ((count++))
    done

    if is_port_free "$port"; then
        echo "✅ Port $port ist erreichbar"
        return 0
    else
        echo "❌ Timeout: Port $port wurde nicht frei"
        return 1
    fi
}

find_free_port() {
    local port=$WUIPort
    while ! is_port_free "$port"; do
        echo "⚠️  Port $port ist belegt, versuche $((port+1))"
        ((port++))
        [ $port -gt 65535 ] && { echo "❌ Kein freier Port gefunden!"; exit 1; }
    done
    WUIPort=$port
    echo "✅ Verwende Port $WUIPort"
}

start_server() {
    echo "🚀 Starte Open-WebUI in Screen-Session '$ScreenSessionName'..."
    cd "$DCRoot" || { echo "Fehler: Verzeichnis $DCRoot nicht gefunden!"; exit 1; }
    
    screen -dmS "$ScreenSessionName" bash -c "
        source venv/bin/activate
        open-webui serve --port $WUIPort --host 0.0.0.0
    "
    
    sleep 2
    wait_for_port "$WUIPort"
    
    echo "🌐 Öffne Browser..."
    $Browser "http://localhost:$WUIPort" &>/dev/null &
}

stop_server() {
    echo "🛑 Beende Open-WebUI..."
    screen -S "$ScreenSessionName" -X quit 2>/dev/null
    sleep 1
    echo "✅ Server wurde beendet."
}

# ====================== HAUPTLOGIK ======================

echo "=== Open-WebUI Manager ==="

check_for_running_open_webui_server
if [ $? -eq 0 ]; then
    echo "✅ Open-WebUI läuft bereits (Screen: $ScreenSessionName)"
    echo
    read -p "Möchtest du den Server [b]eenden oder [n]eu starten? (Enter = beenden) " choice
    choice=${choice:-b}
    
    case "$choice" in
        [Nn]*)
            stop_server
            echo "Neustart wird vorbereitet..."
            sleep 2
            find_free_port
            start_server
            ;;
        *)
            stop_server
            ;;
    esac
else
    echo "Open-WebUI läuft nicht."
    find_free_port
    start_server
fi
