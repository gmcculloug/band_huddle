#!/bin/bash

# SSL Certificate Renewal Script for Band Huddle
# This script is designed to be run from cron for automatic certificate renewal

# Configuration - UPDATE THESE VALUES
DOMAIN="your-domain.com"
EMAIL="your-email@domain.com"
BAND_HUDDLE_PATH="/path/to/band-huddle"

# Logging
LOG_FILE="/var/log/band-huddle-ssl-renewal.log"

# Create log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE"
}

# Change to Band Huddle directory
cd "$BAND_HUDDLE_PATH" || {
    log "ERROR: Could not change to Band Huddle directory: $BAND_HUDDLE_PATH"
    exit 1
}

log "Starting SSL certificate renewal for $DOMAIN"

# Run the renewal
if ./scripts/setup-letsencrypt-fedora.sh -d "$DOMAIN" -e "$EMAIL" -r; then
    log "SSL certificate renewal completed successfully"
else
    log "ERROR: SSL certificate renewal failed"
    log "NOTE: Let's Encrypt requires port 80 to be open and accessible from the internet."
    log "If this server is behind a router or firewall, ensure port 80 is forwarded to this server."
    log "Check your router/firewall port forwarding settings and try again."
    exit 1
fi

log "SSL certificate renewal process finished"