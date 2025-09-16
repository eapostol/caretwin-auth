# CareTwin Authentication

A comprehensive Keycloak-based authentication solution for the CareTwin ecosystem. This repository provides a centralized, agnostic authentication service that can be integrated with multiple applications including the LiDAR iOS App, web model viewer, and Python 3DGS API Service.

## 🏗️ Architecture

This authentication system is built on Keycloak and provides:

- **Centralized Authentication**: Single sign-on (SSO) across all CareTwin applications
- **Multi-Platform Support**: Integration examples for iOS, Web, and Python applications
- **Role-Based Access Control**: Granular permission management
- **OAuth 2.0 / OpenID Connect**: Industry-standard authentication protocols
- **Custom Theming**: CareTwin-branded authentication experience

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Git

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd caretwin-auth
   ```

2. **Run the setup script**
   ```bash
   ./scripts/setup.sh
   ```

3. **Access Keycloak**
   - Admin Console: http://localhost:8080/admin
   - Username: `admin`
   - Password: `admin123` (change this immediately!)

### Development Setup

For a complete development environment with sample data:

```bash
./scripts/dev-setup.sh
```

## 📱 Integration Examples

### iOS Application (Swift)

```swift
let auth = CareTwinAuth()

// Login
auth.login { result in
    switch result {
    case .success(let user):
        print("Logged in as: \(user.name)")
    case .failure(let error):
        print("Login failed: \(error)")
    }
}

// Check authentication
if auth.isAuthenticated() {
    // User is logged in
}

// Check roles
if auth.hasRole("admin") {
    // User has admin role
}
```

### Web Application (JavaScript/React)

```javascript
import CareTwinAuth from './caretwin-auth';

const auth = new CareTwinAuth();

// Login
auth.login();

// Check authentication
if (auth.isAuthenticated()) {
    // User is logged in
}

// Make authenticated API calls
const response = await auth.apiRequest('/api/models');
```

### Python API Service (FastAPI)

```python
from keycloak_auth import KeycloakAuth, get_current_user, require_role

# Protect endpoints
@app.get("/protected")
async def protected_endpoint(current_user = Depends(get_current_user)):
    return {"user": current_user["preferred_username"]}

# Role-based protection
@app.get("/admin-only")
async def admin_endpoint(current_user = Depends(require_role("admin"))):
    return {"message": "Admin access granted"}
```

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Keycloak Configuration
KEYCLOAK_ADMIN_PASSWORD=your_secure_admin_password
KC_HOSTNAME=localhost
KC_HOSTNAME_PORT=8080

# Database Configuration
DB_USERNAME=keycloak
DB_PASSWORD=your_secure_db_password

# Client Configurations
IOS_CLIENT_ID=lidar-ios-app
WEB_CLIENT_ID=lidar-web-viewer
API_CLIENT_ID=3dgs-api-service
```

### Client Applications

The system includes three pre-configured clients:

1. **lidar-ios-app**: Mobile application for LiDAR scanning
2. **lidar-web-viewer**: Web application for model viewing
3. **3dgs-api-service**: Python API service for 3D Gaussian Splatting

## 📚 Documentation

### Repository Structure

```
caretwin-auth/
├── docker-compose.yml          # Docker services configuration
├── .env.example               # Environment variables template
├── keycloak/
│   ├── imports/               # Realm configuration
│   └── themes/                # Custom CareTwin theme
├── examples/
│   ├── ios/                   # iOS integration example
│   ├── web/                   # Web integration example
│   └── python-api/            # Python API integration example
├── scripts/
│   ├── setup.sh              # Initial setup script
│   ├── dev-setup.sh           # Development environment setup
│   └── backup.sh              # Backup script
└── README.md
```

### Realm Configuration

The CareTwin realm includes:

- **Roles**: `user`, `admin`, `api_user`
- **Groups**: `administrators`, `users`
- **Authentication Flows**: Standard OAuth 2.0 / OpenID Connect
- **Security Policies**: Brute force protection, password policies

### Security Features

- **PKCE Support**: For mobile applications
- **Token Refresh**: Automatic token renewal
- **Session Management**: Configurable session timeouts
- **Brute Force Protection**: Account lockout after failed attempts
- **SSL/TLS**: External SSL requirement for production

## 🛠️ Development

### Running in Development

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Testing Authentication

1. **Web Flow Test**:
   - Visit: http://localhost:8080/realms/caretwin/protocol/openid-connect/auth?client_id=lidar-web-viewer&redirect_uri=http://localhost:3000&response_type=code&scope=openid

2. **API Testing**:
   ```bash
   # Get client credentials token
   curl -X POST http://localhost:8080/realms/caretwin/protocol/openid-connect/token \
     -d "grant_type=client_credentials" \
     -d "client_id=3dgs-api-service" \
     -d "client_secret=api-service-client-secret-change-in-production"
   ```

### Customization

#### Custom Theme

The CareTwin theme is located in `keycloak/themes/caretwin/`. Customize:

- `login/resources/css/caretwin.css` - Login page styling
- `account/resources/css/caretwin.css` - Account page styling

#### Adding New Clients

1. Edit `keycloak/imports/caretwin-realm.json`
2. Add new client configuration
3. Restart Keycloak: `docker-compose restart keycloak`

## 🔒 Production Deployment

### Security Checklist

- [ ] Change default admin password
- [ ] Update all client secrets
- [ ] Configure SSL/TLS certificates
- [ ] Set up proper database backup
- [ ] Configure monitoring and logging
- [ ] Review and adjust session timeouts
- [ ] Enable additional security features

### Environment Configuration

1. **Production Environment Variables**:
   ```bash
   KEYCLOAK_ADMIN_PASSWORD=strong_random_password
   KC_HOSTNAME=your-auth-domain.com
   KC_HOSTNAME_PORT=443
   DB_PASSWORD=strong_database_password
   ```

2. **SSL Configuration**:
   - Configure reverse proxy (nginx/Apache)
   - Set `KC_HOSTNAME_STRICT_HTTPS=true`
   - Update redirect URIs to HTTPS

3. **Database**:
   - Use external PostgreSQL for production
   - Configure regular backups
   - Set up monitoring

### Backup and Recovery

```bash
# Create backup
./scripts/backup.sh

# Backups are stored in backups/ directory
# Restore instructions are provided in backup output
```

## 🤝 Integration with CareTwin Applications

### LiDAR iOS App

The iOS app uses OAuth 2.0 with PKCE for secure authentication:

- **Redirect URI**: `com.caretwin.lidar://oauth/callback`
- **Scopes**: `openid profile email`
- **Features**: Biometric authentication support, automatic token refresh

### Web Model Viewer

The web application uses Authorization Code flow:

- **Redirect URI**: `https://your-web-app-domain.com/*`
- **Features**: Session management, role-based UI components

### Python 3DGS API Service

The API service supports multiple authentication methods:

- **Client Credentials**: For service-to-service authentication
- **Bearer Token**: For user-authenticated requests
- **Features**: FastAPI middleware, role-based endpoints

## 📞 Support

For questions and support:

1. Check the integration examples in `examples/`
2. Review Keycloak documentation: https://www.keycloak.org/documentation
3. Check Docker logs: `docker-compose logs -f keycloak`

## 📄 License

[Add your license information here]

---

**CareTwin Authentication** - Secure, scalable authentication for the CareTwin ecosystem.
