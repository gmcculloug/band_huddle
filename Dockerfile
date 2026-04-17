# Use Ruby 4.0 slim image as base
FROM ruby:4.0-slim

# Set working directory
WORKDIR /app

# Install system dependencies including OpenSSL for SSL certificates
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    postgresql-client \
    libpq-dev \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby gems
RUN bundle install

# Copy application code
COPY . .

# Create directories for logs and SSL certificates
RUN mkdir -p /app/logs /app/ssl

# Generate SSL certificate if not provided via volume mount
RUN if [ ! -f /app/ssl/server.crt ]; then \
        openssl req -x509 -newkey rsa:4096 -keyout /app/ssl/server.key -out /app/ssl/server.crt \
        -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=localhost"; \
    fi

# Set environment variables
ENV RACK_ENV=production
ENV PORT=4567

# Expose HTTPS port
EXPOSE 4567

# Create a non-root user for security
RUN useradd -m -u 1000 band-huddle && \
    chown -R band-huddle:band-huddle /app
USER band-huddle

# Health check (use HTTPS with self-signed cert)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -k -f https://localhost:4567/ || exit 1

# Start the application with database migration
CMD ["sh", "-c", "bundle exec rake db:migrate && ruby app.rb"] 
