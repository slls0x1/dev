#!/bin/bash
set -e

echo "=== Importing GOST Certificates to Remote Host ==="

echo "Verifying local files..."
for file in web.au-team.irpo.key web.au-team.irpo.cer docker.au-team.irpo.key docker.au-team.irpo.cer; do
    if [ ! -f "$file" ]; then
        echo "Error: $file not found in the current directory."
        exit 1
    fi
done

echo "Uploading certificates to root@172.16.1.1..."
scp web.au-team.irpo.key root@172.16.1.1:~/
scp web.au-team.irpo.cer root@172.16.1.1:~/
scp docker.au-team.irpo.key root@172.16.1.1:~/
scp docker.au-team.irpo.cer root@172.16.1.1:~/

echo "Done! All certificates transferred successfully."