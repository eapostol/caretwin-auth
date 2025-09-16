#!/bin/bash

# CareTwin Keycloak Setup Script
# This script sets up the Keycloak authentication environment

set -e

echo "🚀 Setting up CareTwin Keycloak Authentication..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created. Please edit it with your specific configuration."
else
    echo "✅ .env file already exists."
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p keycloak/imports
mkdir -p keycloak/themes/caretwin/login/resources/{css,js,img}
mkdir -p keycloak/themes/caretwin/account/resources/{css,js,img}
mkdir -p postgres_data

# Set proper permissions
chmod -R 755 keycloak/
chmod 644 keycloak/imports/*
chmod 644 keycloak/themes/caretwin/**/*

echo "🐳 Starting Docker containers..."

# Start the services
docker-compose up -d

echo "⏳ Waiting for services to be ready..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
until docker-compose exec -T postgres pg_isready -U keycloak; do
    sleep 2
done

echo "Waiting for Keycloak..."
until curl -f http://localhost:8080/realms/caretwin > /dev/null 2>&1; do
    sleep 5
done

echo "✅ Services are ready!"

echo "
🎉 CareTwin Keycloak is now running!

📊 Access Points:
- Keycloak Admin Console: http://localhost:8080/admin
- Keycloak Realm: http://localhost:8080/realms/caretwin
- PostgreSQL: localhost:5432

🔑 Default Credentials:
- Admin Username: admin
- Admin Password: admin123 (change this in production!)

📖 Next Steps:
1. Log into the admin console and change the default admin password
2. Review and update client secrets in the realm configuration
3. Configure your applications with the client credentials
4. Update the .env file with production values

🔧 Management Commands:
- Stop services: docker-compose down
- View logs: docker-compose logs -f
- Restart: docker-compose restart

📚 Documentation:
See the README.md and examples/ directory for integration guides.
"