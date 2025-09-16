FROM quay.io/keycloak/keycloak:26.0
ENV KC_HEALTH_ENABLED=true
RUN /opt/keycloak/bin/kc.sh build
ENTRYPOINT ["/opt/keycloak/bin/kc.sh","start",
  "--http-enabled=true",
  "--proxy-headers","xforwarded"
]


