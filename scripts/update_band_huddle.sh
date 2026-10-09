#!/usr/bin/env bash
set -euo pipefail

git pull --ff-only
docker build -t band-huddle .

# Ask user if they want to run the db migration
read -r -p "Run db migration before starting? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Running db migration..."
    docker compose run --rm db-migrate
    echo ""
fi

docker compose up --scale band-huddle=2 -d --no-deps band-huddle

# Ask user if they want to clear container images
read -r -p "Clear container images? [Y/n] " response
if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
    docker image prune --all --force
fi
