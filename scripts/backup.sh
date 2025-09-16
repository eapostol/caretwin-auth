#!/bin/bash

# CareTwin Keycloak Backup Script
# This script creates a backup of the current Keycloak configuration

set -e

BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="keycloak_backup_${TIMESTAMP}.tar.gz"

echo "📦 Creating backup of CareTwin Keycloak configuration..."

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Docker containers are not running. Please start them first with 'docker-compose up -d'"
    exit 1
fi

# Create temporary directory for backup
TEMP_DIR=$(mktemp -d)

echo "🗄️ Exporting realm configuration..."

# Export realm configuration
docker-compose exec -T keycloak /opt/keycloak/bin/kc.sh export \
    --realm caretwin \
    --file /tmp/caretwin-realm-export.json \
    --users realm_file

# Copy exported file
docker cp $(docker-compose ps -q keycloak):/tmp/caretwin-realm-export.json $TEMP_DIR/

echo "💾 Backing up database..."

# Backup PostgreSQL database
docker-compose exec -T postgres pg_dump -U keycloak keycloak > $TEMP_DIR/keycloak_db.sql

echo "🎨 Backing up themes..."

# Copy themes
cp -r keycloak/themes $TEMP_DIR/

echo "⚙️ Backing up configuration files..."

# Copy configuration files
cp .env $TEMP_DIR/ 2>/dev/null || echo "No .env file found"
cp docker-compose.yml $TEMP_DIR/
cp -r keycloak/imports $TEMP_DIR/ 2>/dev/null || echo "No imports directory found"

echo "📁 Creating archive..."

# Create compressed archive
cd $TEMP_DIR
tar -czf "../${BACKUP_DIR}/${BACKUP_FILE}" .
cd - > /dev/null

# Cleanup
rm -rf $TEMP_DIR

echo "✅ Backup completed successfully!"
echo "📦 Backup file: ${BACKUP_DIR}/${BACKUP_FILE}"

# Show backup size
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
echo "📊 Backup size: $BACKUP_SIZE"

echo "
🔄 To restore from this backup:
1. Stop current services: docker-compose down
2. Clear volumes: docker volume rm caretwin-auth_postgres_data
3. Extract backup: tar -xzf ${BACKUP_DIR}/${BACKUP_FILE}
4. Restore database and restart services
"