#!/bin/bash
# Remove default nginx site before starting RAGFlow
rm -f /etc/nginx/sites-enabled/default

# Generate service_conf.yaml from template with environment variables
envsubst </ragflow/conf/service_conf.yaml.template >/ragflow/conf/service_conf.yaml

exec ./entrypoint.sh "$@"
