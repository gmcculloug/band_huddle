# Band Huddle Docker Configuration

This document explains how to run Band Huddle with Docker using HTTPS and an external PostgreSQL database.

## Configuration Changes

The Docker setup has been updated to:
- ✅ **HTTPS Support**: Automatically generates self-signed SSL certificates
- ✅ **External PostgreSQL**: Connects to your existing PostgreSQL database
- ✅ **Environment-based Configuration**: Uses `.env` file for settings

## Quick Start

### 1. Configure Environment

Copy the example environment file and edit with your settings:

```bash
cp .env.example .env
```

Edit `.env` with your database details:

```bash
# Required: Account creation secret
BAND_HUDDLE_ACCT_CREATION_SECRET=your_secret_key_here

# Required: External PostgreSQL connection
DATABASE_HOST=your_postgres_host
DATABASE_PORT=5432
DATABASE_NAME=band-huddle_production
DATABASE_USERNAME=your_db_user
DATABASE_PASSWORD=your_db_password
```

### 2. Run with Docker Compose

```bash
# Build and start the application
docker-compose up -d

# View logs
docker-compose logs -f band-huddle
```

### 3. Access the Application

- **HTTPS URL**: `https://localhost:4567`

⚠️ **Browser Warning**: You'll see a security warning due to the self-signed certificate. Click "Advanced" then "Proceed to localhost".

## Updating an Existing Deployment

From the application checkout on the deployment host, run:

```bash
./scripts/update_band_huddle.sh
```

The script fast-forward pulls the configured branch, builds the application image, runs pending database migrations, and then updates the application containers.

## Features

### HTTPS/SSL Support
- Automatically generates self-signed certificates in the container
- You can provide custom certificates by mounting them to `/app/ssl/`
- Health checks use HTTPS endpoints

### External Database Support
- No internal PostgreSQL container
- Connects to your existing PostgreSQL instance
- Automatic database migration on startup
- Supports both individual connection parameters and `DATABASE_URL`

### Custom SSL Certificates (Optional)

To use your own SSL certificates, mount them as volumes:

```yaml
volumes:
  - ./logs:/app/logs
  - ./custom-ssl:/app/ssl  # Mount your certificates here
```

Place your certificates in `./custom-ssl/`:
- `server.crt` - SSL certificate
- `server.key` - Private key

## Troubleshooting

### Database Connection Issues
1. Verify your PostgreSQL server is accessible from Docker
2. Check firewall settings (PostgreSQL typically uses port 5432)
3. Ensure database and user exist with proper permissions

### SSL Certificate Issues
1. Certificates are automatically generated if not found
2. Check container logs for SSL generation errors
3. Verify mounted certificate files have correct permissions

### Environment Variables
- Use `docker-compose logs band-huddle` to see startup messages
- Verify environment variables are set correctly in `.env`
- Check that `BAND_HUDDLE_ACCT_CREATION_SECRET` is configured

## Previous Internal PostgreSQL

If you were using the internal PostgreSQL container, you can migrate your data:

1. Export data from the old container
2. Import into your external PostgreSQL
3. Update your `.env` file with new connection details
4. Restart with the new configuration

## Development vs Production

This configuration is production-ready but you may want to:
- Use a reverse proxy (nginx, Apache) for additional SSL features
- Configure proper SSL certificates from a CA (Let's Encrypt, etc.)
- Set up database backups and monitoring
- Configure log aggregation
