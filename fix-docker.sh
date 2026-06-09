#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root."
    exit 1
fi

echo "=== Fixing Bulma CSS Path in Docker Container ==="

echo "Checking if container 'testapp' is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^testapp$"; then
    echo "Error: container 'testapp' is not running."
    exit 1
fi

echo "Replacing static CSS path in app/site/site.htm..."
docker exec testapp sed -i 's|href="{{ url_for('"'"'static'"'"', path='"'"'/css/bulma.css'"'"') }}"|href="/static/css/bulma.css"|g' app/site/site.html

echo "Verifying replacement..."
if docker exec testapp grep -q 'href="/static/css/bulma.css"' app/site/site.html; then
    echo "Success: CSS path updated correctly."
else
    echo "Warning: replacement failed. Please check the file manually."
    exit 1
fi

echo "Done! Container configuration patched."