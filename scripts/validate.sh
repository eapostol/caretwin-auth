#!/bin/bash

# CareTwin Auth Validation Script
# This script validates the repository structure and configuration

set -e

echo "🔍 Validating CareTwin Auth Repository..."

# Check required files exist
REQUIRED_FILES=(
    "docker-compose.yml"
    ".env.example"
    ".gitignore"
    "README.md"
    "DEPLOYMENT.md"
    "keycloak/imports/caretwin-realm.json"
    "keycloak/themes/caretwin/login/theme.properties"
    "keycloak/themes/caretwin/account/theme.properties"
    "examples/python-api/keycloak_auth.py"
    "examples/python-api/main.py"
    "examples/python-api/requirements.txt"
    "examples/web/caretwin-auth.js"
    "examples/web/AuthProvider.jsx"
    "examples/web/App.jsx"
    "examples/web/package.json"
    "examples/ios/CareTwinAuth.swift"
    "examples/ios/ContentView.swift"
    "scripts/setup.sh"
    "scripts/dev-setup.sh"
    "scripts/backup.sh"
)

echo "📁 Checking required files..."
MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    else
        echo "✅ $file"
    fi
done

if [ ${#MISSING_FILES[@]} -ne 0 ]; then
    echo "❌ Missing files:"
    for file in "${MISSING_FILES[@]}"; do
        echo "   - $file"
    done
    exit 1
fi

echo "📋 Checking file permissions..."

# Check script permissions
for script in scripts/*.sh; do
    if [ ! -x "$script" ]; then
        echo "❌ $script is not executable"
        exit 1
    else
        echo "✅ $script is executable"
    fi
done

echo "🔧 Validating configuration files..."

# Check if keycloak realm config is valid JSON
if ! python3 -m json.tool keycloak/imports/caretwin-realm.json > /dev/null 2>&1; then
    echo "❌ keycloak/imports/caretwin-realm.json is not valid JSON"
    exit 1
else
    echo "✅ Keycloak realm configuration is valid JSON"
fi

# Check if package.json files are valid
for package_json in examples/*/package.json; do
    if [ -f "$package_json" ]; then
        if ! python3 -m json.tool "$package_json" > /dev/null 2>&1; then
            echo "❌ $package_json is not valid JSON"
            exit 1
        else
            echo "✅ $package_json is valid JSON"
        fi
    fi
done

echo "🎯 Checking client configurations..."

# Check if all three clients are configured in the realm
CLIENTS=("lidar-ios-app" "lidar-web-viewer" "3dgs-api-service")
for client in "${CLIENTS[@]}"; do
    if grep -q "\"clientId\": \"$client\"" keycloak/imports/caretwin-realm.json; then
        echo "✅ Client $client is configured"
    else
        echo "❌ Client $client is not found in realm configuration"
        exit 1
    fi
done

echo "📊 Repository statistics:"
echo "   - Total files: $(find . -type f | wc -l)"
echo "   - Code files: $(find . -name "*.py" -o -name "*.js" -o -name "*.jsx" -o -name "*.swift" | wc -l)"
echo "   - Config files: $(find . -name "*.json" -o -name "*.yml" -o -name "*.yaml" | wc -l)"
echo "   - Documentation: $(find . -name "*.md" | wc -l)"
echo "   - Scripts: $(find scripts/ -name "*.sh" | wc -l)"

echo "
✅ All validations passed!

🚀 Next steps:
1. Copy .env.example to .env and configure your settings
2. Run ./scripts/setup.sh to start the authentication service
3. Follow the integration examples in the examples/ directory
4. See DEPLOYMENT.md for production deployment guidance

Happy authenticating! 🔐
"