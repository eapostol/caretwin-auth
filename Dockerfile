# Keycloak LTS-ish image; update version as desired
FROM quay.io/keycloak/keycloak:26.0

# Enable health endpoints (optional but recommended)
ENV KC_HEALTH_ENABLED=true

# Build step (optimizes config into a fast runtime image)
RUN /opt/keycloak/bin/kc.sh build

# Start: http enabled (Render provides TLS), honor reverse proxy headers,
# and bind to $PORT so Render can route traffic.
ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", 
  "--http-enabled=true",
  "--http-port=${PORT}",
  "--proxy=edge"]
