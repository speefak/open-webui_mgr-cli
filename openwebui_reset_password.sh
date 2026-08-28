#!/usr/bin/env bash
#
# openwebui_reset_password.sh
# Reset the password of an Open WebUI user directly in the SQLite database.
#
# Author: Speefak
#
# Usage:
#   ./openwebui_reset_password.sh
#   ./openwebui_reset_password.sh -db /path/to/webui.db -u <user-id> -p <new-password>
#
# Options:
#   -db, --database   Path to webui.db (skips auto-detection)
#   -u,  --user       User ID to update (skips interactive selection)
#   -p,  --password   New password (skips interactive prompt)
#   -h,  --help       Show this help
#
set -euo pipefail

DB_PATH=""
USER_ID=""
NEW_PASSWORD=""

usage() {
    grep '^#' "$0" | sed -e 's/^#//' -e '1d'
    exit 0
}

# --- Argument parsing ---------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -db|--database) DB_PATH="$2"; shift 2 ;;
        -u|--user)      USER_ID="$2"; shift 2 ;;
        -p|--password)  NEW_PASSWORD="$2"; shift 2 ;;
        -h|--help)      usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Dependency check ----------------------------------------------------
for cmd in sqlite3 htpasswd; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed." >&2
        [[ "$cmd" == "htpasswd" ]] && echo "Install with: sudo apt install apache2-utils" >&2
        exit 1
    fi
done

# --- Locate the database --------------------------------------------------
if [[ -z "$DB_PATH" ]]; then
    echo "Searching for webui.db ..."
    mapfile -t FOUND_DBS < <(locate -e webui.db 2>/dev/null | grep -E 'webui\.db$' || true)

    if [[ ${#FOUND_DBS[@]} -eq 0 ]]; then
        echo "Nothing found via 'locate', falling back to 'find' (this may take a moment) ..."
        mapfile -t FOUND_DBS < <(find / -xdev -name "webui.db" -type f 2>/dev/null)
    fi

    if [[ ${#FOUND_DBS[@]} -eq 0 ]]; then
        echo "Error: No webui.db found. Specify the path manually with -db." >&2
        exit 1
    elif [[ ${#FOUND_DBS[@]} -eq 1 ]]; then
        DB_PATH="${FOUND_DBS[0]}"
        echo "Found database: $DB_PATH"
    else
        echo "Multiple database files found, please choose one:"
        select db in "${FOUND_DBS[@]}"; do
            [[ -n "$db" ]] && DB_PATH="$db" && break
            echo "Invalid selection."
        done
    fi
fi

if [[ ! -f "$DB_PATH" ]]; then
    echo "Error: Database file not found: $DB_PATH" >&2
    exit 1
fi

# --- Select user -----------------------------------------------------------
if [[ -z "$USER_ID" ]]; then
    mapfile -t USERS < <(sqlite3 -separator '|' "$DB_PATH" "SELECT id, name, email FROM user;")

    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo "Error: No users found in database." >&2
        exit 1
    fi

    echo ""
    echo "Available users:"
    LABELS=()
    IDS=()
    for entry in "${USERS[@]}"; do
        id="${entry%%|*}"
        rest="${entry#*|}"
        name="${rest%%|*}"
        email="${rest#*|}"
        IDS+=("$id")
        LABELS+=("$name <$email> ($id)")
    done

    select label in "${LABELS[@]}"; do
        if [[ -n "$label" ]]; then
            USER_ID="${IDS[$((REPLY-1))]}"
            break
        fi
        echo "Invalid selection."
    done
fi

# --- Verify user exists ------------------------------------------------------
EXISTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM user WHERE id='${USER_ID}';")
if [[ "$EXISTS" -eq 0 ]]; then
    echo "Error: No user found with id '$USER_ID'." >&2
    exit 1
fi

# --- Get new password --------------------------------------------------------
if [[ -z "$NEW_PASSWORD" ]]; then
    while true; do
        read -rs -p "New password: " NEW_PASSWORD; echo
        read -rs -p "Confirm password: " CONFIRM; echo
        if [[ "$NEW_PASSWORD" == "$CONFIRM" && -n "$NEW_PASSWORD" ]]; then
            break
        fi
        echo "Passwords do not match or are empty. Try again."
    done
fi

# --- Generate bcrypt hash and update database --------------------------------
HASH=$(htpasswd -bnBC 10 "" "$NEW_PASSWORD" | tr -d ':')

sqlite3 "$DB_PATH" "UPDATE auth SET password='${HASH}' WHERE id='${USER_ID}';"

echo ""
echo "Password successfully updated for user ID: $USER_ID"
echo "Database: $DB_PATH"
