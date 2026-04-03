#!/bin/bash

# Let's Encrypt SSL Setup Script for Band Huddle on Fedora
# This script sets up SSL certificates using Certbot for production deployment

set -e  # Exit on any error

# Configuration
DOMAINS=()
EMAIL=""
WEBROOT_PATH="./certbot/www"
SSL_DIR="./ssl"
NGINX_CONF_DIR="./config"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Help function
show_help() {
    cat << EOF
Let's Encrypt SSL Setup Script for Band Huddle

Usage: $0 -d DOMAIN1 [-d DOMAIN2 ...] -e EMAIL [OPTIONS]

Required Arguments:
    -d DOMAIN    Your domain name (can be specified multiple times, e.g., -d example.com -d www.example.com)
    -e EMAIL     Email address for Let's Encrypt notifications

Optional Arguments:
    -s           Staging mode (use Let's Encrypt staging server for testing)
    -r           Renewal mode (renew existing certificates)
    -f           Force renewal (even if certificates are not due for renewal)
    -h           Show this help message

Examples:
    # Initial setup with single domain
    $0 -d yourdomain.com -e admin@yourdomain.com

    # Initial setup with multiple domains
    $0 -d yourdomain.com -d www.yourdomain.com -e admin@yourdomain.com

    # Test with staging server first
    $0 -d yourdomain.com -d www.yourdomain.com -e admin@yourdomain.com -s

    # Renew certificates
    $0 -d yourdomain.com -d www.yourdomain.com -e admin@yourdomain.com -r

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons."
        error "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check if we're on Fedora
    if ! grep -q "Fedora" /etc/os-release; then
        warning "This script is designed for Fedora. It may work on other systems but is untested."
    fi

    # Check if Docker and Docker Compose are installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    # Check if we're in the Band Huddle directory
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        error "docker-compose.yml not found. Please run this script from the Band Huddle project root."
        exit 1
    fi

    log "Prerequisites check passed!"
}

# Install Certbot
install_certbot() {
    log "Installing Certbot..."

    # Update package list
    sudo dnf update -y

    # Install Certbot and nginx plugin
    if ! command -v certbot &> /dev/null; then
        log "Installing certbot and certbot-nginx..."
        sudo dnf install -y certbot python3-certbot-nginx
    else
        log "Certbot is already installed"
    fi

    # Install additional dependencies
    sudo dnf install -y curl openssl

    log "Certbot installation completed!"
}

# Create webroot directory for challenge
setup_webroot() {
    log "Setting up webroot directory for ACME challenge..."

    mkdir -p "$WEBROOT_PATH"
    chown -R $USER:$USER "$WEBROOT_PATH" 2>/dev/null || true

    log "Webroot directory created at $WEBROOT_PATH"
}

# Create temporary nginx config for certificate generation
create_temp_nginx_config() {
    log "Creating temporary nginx configuration for certificate generation..."

    # Create server_name list from domains array
    local server_names=$(printf "%s " "${DOMAINS[@]}")

    cat > "$NGINX_CONF_DIR/nginx-temp.conf" << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Temporary server for ACME challenge
    server {
        listen 80;
        server_name ${server_names};

        # ACME challenge location
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files \$uri =404;
        }

        # Redirect all other traffic to HTTPS (after cert is obtained)
        location / {
            return 301 https://\$host\$request_uri;
        }
    }
}
EOF

    log "Temporary nginx configuration created"
}

# Create production nginx config with SSL
create_production_nginx_config() {
    log "Creating production nginx configuration..."

    # Create server_name list from domains array
    local server_names=$(printf "%s " "${DOMAINS[@]}")

    cat > "$NGINX_CONF_DIR/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;

    # Upstream to Band Huddle app
    upstream band_huddle_app {
        server band-huddle:4567 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # HTTP server - redirects to HTTPS and serves ACME challenges
    server {
        listen 80;
        server_name ${server_names};

        # ACME challenge location
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files \$uri =404;
        }

        # Redirect all other HTTP to HTTPS
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name ${server_names};

        # SSL configuration (Let's Encrypt certificates)
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_trusted_certificate /etc/nginx/ssl/chain.pem;

        # SSL security settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # OCSP stapling
        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 8.8.8.8 8.8.4.4 valid=300s;
        resolver_timeout 5s;

        # Security headers
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Referrer-Policy "strict-origin-when-cross-origin";

        # Proxy settings
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        # Main application
        location / {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://band_huddle_app;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # Static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            proxy_pass http://band_huddle_app;
        }

        # Health check endpoint
        location /health {
            access_log off;
            proxy_pass http://band_huddle_app;
        }
    }
}
EOF

    log "Production nginx configuration created"
}

# Start nginx temporarily for certificate generation
start_temp_nginx() {
    log "Starting nginx with temporary configuration for certificate generation..."

    # Stop existing nginx if running
    docker-compose down nginx 2>/dev/null || true

    # Backup current nginx config
    cp "$NGINX_CONF_DIR/nginx.conf" "$NGINX_CONF_DIR/nginx.conf.backup" 2>/dev/null || true

    # Use temporary config
    cp "$NGINX_CONF_DIR/nginx-temp.conf" "$NGINX_CONF_DIR/nginx.conf"

    # Start nginx with temporary config
    docker-compose up -d nginx

    sleep 10
    log "Temporary nginx configuration started"
}

# Stop temporary nginx and restore production config
stop_temp_nginx() {
    log "Restoring production nginx configuration..."

    # Stop nginx
    docker-compose down nginx 2>/dev/null || true

    # Restore production config
    if [ -f "$NGINX_CONF_DIR/nginx.conf.backup" ]; then
        mv "$NGINX_CONF_DIR/nginx.conf.backup" "$NGINX_CONF_DIR/nginx.conf"
    fi

    log "Production nginx configuration restored"
}

# Obtain SSL certificate
obtain_certificate() {
    local staging_flag=""
    if [[ "$STAGING" == "true" ]]; then
        staging_flag="--staging"
        warning "Using Let's Encrypt staging server (test certificates)"
    fi

    # Build domain arguments for certbot
    local domain_args=""
    for domain in "${DOMAINS[@]}"; do
        domain_args="$domain_args -d $domain"
    done

    log "Obtaining SSL certificate for domains: ${DOMAINS[*]}..."

    # Obtain certificate using webroot
    if sudo certbot certonly \
        --webroot \
        -w "$WEBROOT_PATH" \
        $domain_args \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive \
        $staging_flag; then
        log "Certificate obtained successfully!"
    else
        error "Failed to obtain certificate"
        error ""
        error "NOTE: Let's Encrypt requires port 80 to be open and accessible from the internet."
        error "If this is running behind a router or firewall, ensure port 80 is forwarded to this server."
        error "Check your router/firewall port forwarding settings and try again."
        exit 1
    fi
}

# Copy certificates to SSL directory
copy_certificates() {
    log "Copying certificates to SSL directory..."

    # Create SSL directory if it doesn't exist
    mkdir -p "$SSL_DIR"

    # Use the first domain as the primary domain for certificate path
    local primary_domain="${DOMAINS[0]}"

    # Copy certificates
    sudo cp "/etc/letsencrypt/live/$primary_domain/fullchain.pem" "$SSL_DIR/"
    sudo cp "/etc/letsencrypt/live/$primary_domain/privkey.pem" "$SSL_DIR/"
    sudo cp "/etc/letsencrypt/live/$primary_domain/chain.pem" "$SSL_DIR/"

    # Set proper permissions
    sudo chown -R $USER:$USER "$SSL_DIR"
    chmod 644 "$SSL_DIR"/*.pem

    log "Certificates copied to $SSL_DIR"
}

# Renew certificates
renew_certificates() {
    log "Renewing certificates..."

    local force_flag=""
    if [[ "$FORCE_RENEWAL" == "true" ]]; then
        force_flag="--force-renewal"
        warning "Forcing certificate renewal"
    fi

    sudo certbot renew $force_flag --quiet

    if [[ $? -eq 0 ]]; then
        log "Certificate renewal completed!"
        copy_certificates
        restart_services
    else
        error "Certificate renewal failed"
        exit 1
    fi
}

# Restart services
restart_services() {
    log "Restarting services..."

    # Start all services including nginx with production config
    docker-compose up -d

    log "Services restarted"
}

# Create renewal script
create_renewal_script() {
    log "Creating automatic renewal script..."

    # Build domain arguments for renewal script
    local domain_args=""
    for domain in "${DOMAINS[@]}"; do
        domain_args="$domain_args -d $domain"
    done

    cat > "scripts/renew-ssl.sh" << EOF
#!/bin/bash
# Automatic SSL certificate renewal script for Band Huddle

cd "\$(dirname "\$0")/.."

# Renew certificates
$0 $domain_args -e "$EMAIL" -r

EOF

    chmod +x "scripts/renew-ssl.sh"

    log "Renewal script created at scripts/renew-ssl.sh"
    info "You can add this to cron for automatic renewal:"
    info "0 0 1 * * /path/to/band-huddle/scripts/renew-ssl.sh"
}

# Main execution
main() {
    local STAGING="false"
    local RENEWAL="false"
    local FORCE_RENEWAL="false"

    # Parse command line arguments
    while getopts "d:e:srfh" opt; do
        case ${opt} in
            d )
                DOMAINS+=("$OPTARG")
                ;;
            e )
                EMAIL="$OPTARG"
                ;;
            s )
                STAGING="true"
                ;;
            r )
                RENEWAL="true"
                ;;
            f )
                FORCE_RENEWAL="true"
                ;;
            h )
                show_help
                exit 0
                ;;
            \? )
                error "Invalid option: -$OPTARG"
                show_help
                exit 1
                ;;
        esac
    done

    # Check required arguments
    if [[ ${#DOMAINS[@]} -eq 0 || -z "$EMAIL" ]]; then
        error "At least one domain and email are required"
        show_help
        exit 1
    fi

    log "Starting Let's Encrypt SSL setup for Band Huddle"
    log "Domains: ${DOMAINS[*]}"
    log "Email: $EMAIL"

    check_root
    check_prerequisites

    if [[ "$RENEWAL" == "true" ]]; then
        renew_certificates
    else
        install_certbot
        setup_webroot
        create_temp_nginx_config
        start_temp_nginx

        # Restore nginx config on any error after the temp swap
        trap 'stop_temp_nginx' ERR EXIT

        # Give nginx time to start
        sleep 10

        obtain_certificate
        stop_temp_nginx

        # Clear the trap now that we've cleanly restored
        trap - ERR EXIT
        copy_certificates
        create_production_nginx_config
        create_renewal_script

        log "SSL setup completed successfully!"
        info "You can now start your application with: docker-compose up -d"
        info "Your site will be available at:"
        for domain in "${DOMAINS[@]}"; do
            info "  - https://$domain"
        done
    fi
}

# Run main function with all arguments
main "$@"