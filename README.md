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
