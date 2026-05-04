#!/bin/bash
# =============================================
# Open-WebUI Start Script – saubere Ausgabe v0.2
# =============================================

# === Globale Variablen ===
DCRoot=~/.open-webui
ScreenSessionName="open-webui_server"
WUIPort=3000
Browser="firefox"
MAX_WAIT=45

# === Hilfsfunktionen ===

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

    echo -n "⏳ Warte bis Open-WebUI vollständig gestartet ist"

    while [ $waited -lt $MAX_WAIT ]; do
        if is_port_listening "$port" && http_healthcheck "$port"; then
            echo -e "\r✅ Open-WebUI ist bereit!                          "
            return 0
        fi
        
        sleep 2
        ((waited+=2))
        echo -n "."
    done

    echo -e "\r❌ Timeout: Server hat nicht rechtzeitig geantwortet.          "
    return 1
}

find_free_port() {
    local port=$WUIPort
    while ss -tuln | grep -q ":$port "; do
        echo "⚠️  Port $port ist belegt, versuche $((port+1))"
        ((port++))
        [ $port -gt 65535 ] && { echo "❌ Kein freier Port!"; exit 1; }
    done
    WUIPort=$port
}

start_server() {
    echo "🚀 Starte Open-WebUI in Screen-Session '$ScreenSessionName'..."
    cd "$DCRoot" || { echo "❌ Verzeichnis $DCRoot nicht gefunden!"; exit 1; }
    
    screen -dmS "$ScreenSessionName" bash -c "
        source venv/bin/activate
        open-webui serve --port $WUIPort --host 0.0.0.0
    "

    sleep 2
    wait_for_server_ready "$WUIPort"
    
    echo "🌐 Öffne Browser..."
    $Browser "http://localhost:$WUIPort" &>/dev/null &
}

stop_server() {
    echo "🛑 Beende Open-WebUI..."
    screen -S "$ScreenSessionName" -X quit 2>/dev/null
    sleep 1.5
    echo "✅ Server wurde beendet."
}

# ====================== HAUPTLOGIK ======================

echo "=== Open-WebUI Manager ==="

if check_for_running_open_webui_server; then
    echo "✅ Open-WebUI läuft bereits."
    echo
    read -p "Server [b]eenden oder [n]eu starten? (Enter = beenden) " choice
    choice=${choice:-b}
    
    case "$choice" in
        [Nn]*)
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
    echo "Open-WebUI ist nicht gestartet."
    find_free_port
    start_server
fi
