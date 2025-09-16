#!/bin/bash

# CareTwin Keycloak Development Setup Script
# This script sets up a development environment with sample data

set -e

echo "🛠️ Setting up CareTwin Keycloak Development Environment..."

# Run the basic setup first
./scripts/setup.sh

echo "🔧 Configuring development environment..."

# Wait a bit more for Keycloak to fully initialize
sleep 10

echo "✅ Development environment is ready!"

echo "
🚀 Development Setup Complete!

The following has been configured:
- Keycloak server with CareTwin realm
- Three pre-configured clients:
  * lidar-ios-app (iOS application)
  * lidar-web-viewer (Web application)  
  * 3dgs-api-service (Python API service)
- Sample admin user (admin/admin123)
- Custom CareTwin theme

📱 Test the integrations:
1. iOS: Use the example code in examples/ios/
2. Web: Use the example code in examples/web/
3. Python API: Use the example code in examples/python-api/

🔍 Useful URLs:
- Admin Console: http://localhost:8080/admin
- Realm Info: http://localhost:8080/realms/caretwin
- OpenID Config: http://localhost:8080/realms/caretwin/.well-known/openid_configuration

Happy coding! 🎉
"