# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a production WordPress site built on the **Bedrock** framework, running in a containerized environment with Docker Compose. The setup includes WordPress FPM, Nginx, MySQL 8.3, and SSL certificate generation, designed for modern development workflows.

**Key Technologies:**
- WordPress core managed via Composer
- PHP 8.3 with FPM
- MySQL 8.3 with SSL encryption
- Nginx 1.25.5 as web server
- Cocoon theme (v2.5.42) with Gutenberg block support
- StaticPress2019 for static site generation

## Common Commands

### Starting and Stopping Services

```bash
# Start all services (database, wordpress-fpm, web, ssl_certificate)
docker-compose up -d

# Stop all services
docker-compose down

# View logs for a specific service
docker-compose logs -f wordpress-fpm
docker-compose logs -f web
docker-compose logs -f database

# Rebuild and restart after changes
docker-compose up -d --build
```

### Development Workflow

```bash
# Execute commands in WordPress container
docker-compose exec wordpress-fpm bash

# Install/update PHP dependencies
docker-compose exec wordpress-fpm composer install
docker-compose exec wordpress-fpm composer update

# Run PHP code standards check (PSR-2)
docker-compose exec wordpress-fpm composer test
docker-compose exec wordpress-fpm phpcs

# WP-CLI commands
docker-compose exec wordpress-fpm wp-cli plugin list
docker-compose exec wordpress-fpm wp-cli theme list
docker-compose exec wordpress-fpm wp-cli user create admin admin@example.com --role=administrator --prompt=user_pass
docker-compose exec wordpress-fpm wp-cli language core install ja
```

### Theme Development (Cocoon)

```bash
# Navigate to theme directory (inside container or locally)
cd wordpress-fpm/web/app/themes/cocoon-master

# Install Node.js dependencies
npm install

# Watch SASS files and auto-compile (development)
npm run watch

# Build theme assets for production
npm run build

# Build Gutenberg blocks
npm run start   # Development mode
cd blocks && npm run build  # Production build
```

### Running Tests

```bash
# PHP code standards (runs phpcs)
docker-compose exec wordpress-fpm composer test

# PHPUnit tests
docker-compose exec wordpress-fpm ./vendor/bin/phpunit
```

### Database Operations

```bash
# Access MySQL CLI
docker-compose exec database mysql -u app -p service

# Database backup files are in backup/initdb.d/
# Uploaded media backups are in backup/inituploads.d/
# These are auto-restored on container initialization if database/uploads are empty
```

## Architecture

### Service Architecture

The application runs as 4 Docker Compose services:

1. **ssl_certificate**: Generates SSL certificates for HTTPS and MySQL SSL connections
2. **database**: MySQL 8.3 with SSL enabled, initialized from backup files
3. **wordpress-fpm**: PHP-FPM container running Bedrock WordPress application
4. **web**: Nginx container serving static files and proxying PHP requests to wordpress-fpm

### Request Flow

```
Client (HTTPS) → Nginx (web:443) → FastCGI → WordPress FPM (wordpress-fpm:9000) → MySQL (database:3306 with SSL)
```

Static files are served directly by Nginx. PHP files are processed by wordpress-fpm via FastCGI protocol on port 9000.

### Directory Structure

**Key Directories:**
- `/wordpress-fpm/config/`: Bedrock configuration files (application.php, environment-specific configs)
- `/wordpress-fpm/web/`: Document root
  - `/web/wp/`: WordPress core (managed by Composer, do not edit)
  - `/web/app/`: Custom content directory
    - `/app/mu-plugins/`: Must-use plugins (autoloaded)
    - `/app/plugins/`: Regular plugins (installed via Composer or manually added)
    - `/app/themes/`: WordPress themes
    - `/app/uploads/`: User-uploaded media (Docker volume)
- `/nginx_conf.d/`: Nginx server configuration
- `/backup/`: Database and upload backups for restoration

**Important:** WordPress core is in `/web/wp/` (not `/wp-content/`). Custom content is in `/web/app/`.

### Volume Sharing

These directories are shared between Nginx and WordPress FPM containers via Docker volumes:
- `plugins`: Plugin files installed by Composer
- `uploads`: User-uploaded media files
- `upgrade`: WordPress upgrade temporary files
- `wordpress`: WordPress core files
- `pki`: SSL certificates

Local directories are mounted for development:
- `wordpress-fpm/config/` → Configuration files
- `wordpress-fpm/web/app/themes/` → Theme development
- `wordpress-fpm/web/app/plugins/staticpress2019-s3/` → Custom plugin

### Environment Configuration

All services are configured via environment variables in `.env` file (not in repository):

**Required variables:**
- `DOMAIN_NAME`: Domain name for SSL certificates
- `DATABASE_ROOT_PASSWORD`: MySQL root password
- `DATABASE_USER_PASSWORD`: MySQL app user password
- `WORDPRESS_ENV`: Environment (production/development/staging)
- `WORDPRESS_AUTH_KEY`, `WORDPRESS_SECURE_AUTH_KEY`, etc.: WordPress salts

**URLs:**
- Frontend: `https://local.${DOMAIN_NAME}`
- Admin: `https://local.${DOMAIN_NAME}/wp/wp-admin`

Generate WordPress salts at: https://roots.io/salts.html

### Bedrock Configuration System

Bedrock uses environment-specific configuration files:

- `config/application.php`: Main configuration (database, auth keys, MySQL SSL)
- `config/environments/production.php`: Production settings (debug off)
- `config/environments/development.php`: Development settings (debug on)
- `config/environments/staging.php`: Staging settings

Configuration is loaded based on `WP_ENV` environment variable.

### MySQL SSL Security

The application enforces SSL for MySQL connections:
- Server certificates generated by `ssl_certificate` service
- Client SSL enabled via `MYSQLI_CLIENT_SSL` flag
- CA certificate path: `/etc/pki/CA/cacert-${DOMAIN_NAME}.pem`

### StaticPress2019 Integration

The StaticPress2019 plugin generates static HTML versions of WordPress pages:
- Static files are generated to `/web/static/` (bind-mounted to host)
- StaticPress2019-S3 plugin uploads static sites to AWS S3
- Nginx timeout set to 10 minutes for rebuild operations

## Theme Development Notes

### Cocoon Theme Structure

The Cocoon theme (`cocoon-master`) is a modern WordPress theme with:
- **Block Editor (Gutenberg) support** via `theme.json`
- **Custom blocks** in `/blocks/` subdirectory (separate npm workspace)
- **SASS compilation** via Gulp 4
- **npm scripts** for build automation

**Development workflow:**
1. Edit SASS files in theme directory
2. Run `npm run watch` to auto-compile CSS
3. For block development, run `npm run start`
4. Build for production with `npm run build`

### Child Theme

There is a child theme at `cocoon-child-master/` for customizations. Always prefer child theme for modifications to avoid losing changes on parent theme updates.

## Important Development Practices

### File Editing Restrictions

- **Do not edit files in `/web/wp/`**: WordPress core is managed by Composer
- **Do not edit `/web/app/plugins/` for Composer-managed plugins**: Use `composer.json` to manage versions
- **Use child theme** for theme customizations
- **Use mu-plugins** for site-specific functionality that must always load

### Code Standards

This project uses PSR-2 coding standards for PHP:
- Run `composer test` before committing
- Configuration in `phpcs.xml`
- Excludes: WordPress core, vendor directory

### SSL Certificate Handling

SSL certificates are auto-generated on startup by the `ssl_certificate` service:
- Certificates cached in `pki` Docker volume
- Domain name set via `DOMAIN_NAME` environment variable
- All services depend on `ssl_certificate` service
- Certificates are shared via volume mounts

### Container Startup Sequence

The `wordpress-fpm` container's `entrypoint.sh` performs these steps on startup:
1. Restore uploaded media from `/docker-entrypoint-inituploads.d/` if `/web/app/uploads/` is empty
2. Install Composer dependencies
3. Wait for SSL certificates to be generated
4. Configure MySQL client SSL certificates
5. Wait for database availability
6. Install Japanese (ja) language pack
7. Start PHP-FPM

### Multi-Stage Docker Build

The Dockerfile has two targets:
- **production**: Minimal image with PHP and Composer dependencies only
- **development**: Includes Node.js and npm for theme development

In `compose.yml`, the target is set to `production`. For development with Node.js support, use `.devcontainer/compose.yml` which overrides to `development` target.

### Adding New Plugins/Themes

**Via Composer (preferred for WordPress.org plugins):**
```bash
# Add plugin from wpackagist
docker-compose exec wordpress-fpm composer require wpackagist-plugin/plugin-name

# Add theme from wpackagist
docker-compose exec wordpress-fpm composer require wpackagist-theme/theme-name
```

**Manually:**
- Place plugin directory in `wordpress-fpm/web/app/plugins/`
- The Bedrock autoloader will automatically load it as a must-use plugin

### Language Support

Japanese language pack is auto-installed on container startup. To add more languages:

```bash
docker-compose exec wordpress-fpm wp-cli language core install es_ES
docker-compose exec wordpress-fpm wp-cli language plugin install --all ja
```

Or add to `composer.json`:
```json
"require": {
  "koodimonni-language/ja": "*",
  "koodimonni-language/es_ES": "*"
}
```
