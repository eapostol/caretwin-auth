# CareTwin Authentication - Production Deployment Guide

This guide covers deploying CareTwin Keycloak authentication to production environments.

## 🏗️ Production Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │  Reverse Proxy  │    │    Keycloak     │
│     (AWS ALB)   │────│   (nginx/CF)    │────│   (Docker)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                               ┌─────────────────┐
                                               │   PostgreSQL    │
                                               │  (AWS RDS/GCP)  │
                                               └─────────────────┘
```

## 🚀 Deployment Options

### Option 1: Docker on Cloud VM

**Recommended for**: Small to medium deployments

1. **Create Cloud VM**:
   - AWS EC2 t3.medium or larger
   - GCP Compute Engine e2-standard-2 or larger
   - Azure Standard B2s or larger

2. **Install Dependencies**:
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Deploy Application**:
   ```bash
   git clone <repository-url>
   cd caretwin-auth
   cp .env.example .env
   # Edit .env with production values
   ./scripts/setup.sh
   ```

### Option 2: Kubernetes Deployment

**Recommended for**: Large scale deployments

```yaml
# keycloak-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:23.0.3
        env:
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://postgres:5432/keycloak
        - name: KC_HOSTNAME
          value: auth.yourdomain.com
        - name: KC_HOSTNAME_STRICT_HTTPS
          value: "true"
        ports:
        - containerPort: 8080
        command: ["start"]
```

### Option 3: Managed Keycloak Services

**Options**:
- Red Hat Single Sign-On (RHSSO)
- Auth0 (with custom configuration)
- AWS Cognito (requires adaptation)

## 🔒 Security Configuration

### SSL/TLS Setup

1. **Certificate Acquisition**:
   ```bash
   # Using Let's Encrypt with Certbot
   sudo apt-get install certbot
   sudo certbot certonly --standalone -d auth.yourdomain.com
   ```

2. **Nginx Configuration**:
   ```nginx
   server {
       listen 443 ssl http2;
       server_name auth.yourdomain.com;
       
       ssl_certificate /etc/letsencrypt/live/auth.yourdomain.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/auth.yourdomain.com/privkey.pem;
       
       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

### Database Security

1. **Use External Database**:
   ```bash
   # AWS RDS PostgreSQL
   KC_DB_URL=jdbc:postgresql://your-db-instance.amazonaws.com:5432/keycloak
   KC_DB_USERNAME=keycloak
   KC_DB_PASSWORD=your_secure_password
   ```

2. **Database Backup**:
   ```bash
   # Automated daily backups
   0 2 * * * pg_dump -h your-db-host -U keycloak keycloak > /backup/keycloak_$(date +\%Y\%m\%d).sql
   ```

### Environment Variables

```bash
# Production .env
KEYCLOAK_ADMIN_PASSWORD=your_ultra_secure_admin_password_min_20_chars
KC_HOSTNAME=auth.yourdomain.com
KC_HOSTNAME_PORT=443
KC_HOSTNAME_STRICT_HTTPS=true

# Database
DB_USERNAME=keycloak
DB_PASSWORD=your_ultra_secure_db_password_min_20_chars

# Application URLs (update these!)
IOS_REDIRECT_URI=com.caretwin.lidar://oauth/callback
WEB_REDIRECT_URI=https://viewer.yourdomain.com/*
API_REDIRECT_URI=https://api.yourdomain.com/*
```

## 📊 Monitoring and Logging

### Health Checks

```bash
# Keycloak health check
curl -f https://auth.yourdomain.com/health/ready

# Database health check
curl -f https://auth.yourdomain.com/health/live
```

### Logging Configuration

1. **Docker Compose Logging**:
   ```yaml
   services:
     keycloak:
       logging:
         driver: "json-file"
         options:
           max-size: "10m"
           max-file: "3"
   ```

2. **External Logging** (Optional):
   - ELK Stack (Elasticsearch, Logstash, Kibana)
   - AWS CloudWatch
   - Google Cloud Logging

### Monitoring Metrics

Monitor these key metrics:
- Response time
- Active sessions
- Failed login attempts
- Database connections
- Memory usage
- CPU usage

## 🔄 Backup and Recovery

### Automated Backup Script

```bash
#!/bin/bash
# /opt/scripts/keycloak-backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup"
S3_BUCKET="your-backup-bucket"

# Create backup
./scripts/backup.sh

# Upload to S3 (optional)
aws s3 cp backups/keycloak_backup_${DATE}.tar.gz s3://${S3_BUCKET}/keycloak/

# Clean old local backups (keep last 7 days)
find $BACKUP_DIR -name "keycloak_backup_*.tar.gz" -mtime +7 -delete
```

### Recovery Procedure

1. **Stop Services**:
   ```bash
   docker-compose down
   ```

2. **Restore Database**:
   ```bash
   # Restore from backup
   psql -h your-db-host -U keycloak keycloak < backup_file.sql
   ```

3. **Restore Configuration**:
   ```bash
   # Extract backup
   tar -xzf keycloak_backup_YYYYMMDD_HHMMSS.tar.gz
   
   # Copy themes and configuration
   cp -r themes/* keycloak/themes/
   ```

4. **Restart Services**:
   ```bash
   docker-compose up -d
   ```

## 🚨 Troubleshooting

### Common Issues

1. **Connection Refused**:
   ```bash
   # Check if service is running
   docker-compose ps
   
   # Check logs
   docker-compose logs keycloak
   ```

2. **Database Connection Error**:
   ```bash
   # Test database connectivity
   docker-compose exec postgres pg_isready -U keycloak
   ```

3. **SSL Certificate Issues**:
   ```bash
   # Check certificate validity
   openssl x509 -in /etc/letsencrypt/live/auth.yourdomain.com/cert.pem -text -noout
   ```

### Performance Tuning

1. **JVM Options**:
   ```yaml
   environment:
     JAVA_OPTS: "-Xms512m -Xmx2048m -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m"
   ```

2. **Database Connection Pool**:
   ```yaml
   environment:
     KC_DB_POOL_INITIAL_SIZE: 5
     KC_DB_POOL_MIN_SIZE: 5
     KC_DB_POOL_MAX_SIZE: 20
   ```

## 📋 Production Checklist

### Pre-Deployment

- [ ] SSL certificates configured
- [ ] Database properly secured
- [ ] All default passwords changed
- [ ] Client secrets updated
- [ ] Backup strategy implemented
- [ ] Monitoring configured
- [ ] Load testing completed

### Post-Deployment

- [ ] Health checks passing
- [ ] All applications can authenticate
- [ ] Backup restoration tested
- [ ] Security scan completed
- [ ] Performance monitoring active
- [ ] Documentation updated

### Security Audit

- [ ] No default credentials in use
- [ ] All endpoints use HTTPS
- [ ] Database access restricted
- [ ] Logs don't contain sensitive data
- [ ] Rate limiting configured
- [ ] Security headers configured

## 📞 Support and Maintenance

### Regular Tasks

- **Weekly**: Review logs for anomalies
- **Monthly**: Security updates and patches
- **Quarterly**: Backup restoration testing
- **Annually**: Security audit and penetration testing

### Contact Information

- **Emergency**: [Your emergency contact]
- **Security Issues**: [Your security team]
- **General Support**: [Your support email]

---

For more detailed information, refer to:
- [Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)