#!/bin/bash
# Remove default nginx site before starting RAGFlow
rm -f /etc/nginx/sites-enabled/default
exec ./entrypoint.sh "$@"
