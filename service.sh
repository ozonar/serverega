#!/bin/bash

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 <ip|alias>"
    exit 1
fi

TARGET="$1"
ALIAS_FILE="./alias.yml"
HOST=""

# alias -> ip
if [[ -f "$ALIAS_FILE" ]]; then
    HOST=$(awk -F': ' -v a="$TARGET" '$1==a {print $2}' "$ALIAS_FILE")
fi

# если не алиас — считаем, что это ip/hostname
[[ -z "$HOST" ]] && HOST="$TARGET"

ssh "$HOST" '
journalctl --since "24 hours ago" -u "*" --no-pager --output=short-unix \
| grep "systemd\[1\]" \
| grep -E "(Stopped|Failed|exited|deactivated)" \
| grep "\.service" \
| grep -v "Deactivated successfully" \
| awk "
{
    ts = \$1
    match(\$0, /([a-zA-Z0-9@._-]+\.service)/, m)
    svc = m[1]

    if (svc == \"\" || svc ~ /^systemd/) next

    count[svc]++
    if (!last[svc] || ts > last[svc]) last[svc] = ts
}
END {
    now = systime()
    for (svc in count) {
        mins = int((now - last[svc]) / 60)
        printf \"%-35s %3d events  last %4d min ago\n\", svc, count[svc], mins
    }
}
" \
| sort -k5 -n
'
