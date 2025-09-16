"""
CareTwin Keycloak Python Integration

This module provides authentication utilities for the Python 3DGS API Service
to integrate with Keycloak for user authentication and authorization.
"""

import os
import jwt
import requests
from datetime import datetime, timedelta
from typing import Dict, Optional, Any
from urllib.parse import urljoin


class KeycloakAuth:
    """Keycloak authentication client for Python applications."""
    
    def __init__(self, 
                 server_url: str = None,
                 realm: str = None,
                 client_id: str = None,
                 client_secret: str = None):
        """
        Initialize Keycloak authentication client.
        
        Args:
            server_url: Keycloak server URL (default from env KEYCLOAK_URL)
            realm: Keycloak realm name (default from env KEYCLOAK_REALM)
            client_id: Client ID (default from env API_CLIENT_ID)
            client_secret: Client secret (default from env API_CLIENT_SECRET)
        """
        self.server_url = server_url or os.getenv('KEYCLOAK_URL', 'http://localhost:8080')
        self.realm = realm or os.getenv('KEYCLOAK_REALM', 'caretwin')
        self.client_id = client_id or os.getenv('API_CLIENT_ID', '3dgs-api-service')
        self.client_secret = client_secret or os.getenv('API_CLIENT_SECRET')
        
        self.base_url = urljoin(self.server_url, f'/realms/{self.realm}/')
        self.token_url = urljoin(self.base_url, 'protocol/openid-connect/token')
        self.userinfo_url = urljoin(self.base_url, 'protocol/openid-connect/userinfo')
        self.certs_url = urljoin(self.base_url, 'protocol/openid-connect/certs')
        
        self._public_keys = None
    
    def get_client_credentials_token(self) -> Dict[str, Any]:
        """
        Get access token using client credentials flow.
        
        Returns:
            Dict containing access token and metadata
        """
        data = {
            'grant_type': 'client_credentials',
            'client_id': self.client_id,
            'client_secret': self.client_secret
        }
        
        response = requests.post(self.token_url, data=data)
        response.raise_for_status()
        
        return response.json()
    
    def exchange_authorization_code(self, code: str, redirect_uri: str) -> Dict[str, Any]:
        """
        Exchange authorization code for tokens.
        
        Args:
            code: Authorization code from OAuth flow
            redirect_uri: Redirect URI used in authorization request
            
        Returns:
            Dict containing tokens and metadata
        """
        data = {
            'grant_type': 'authorization_code',
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'code': code,
            'redirect_uri': redirect_uri
        }
        
        response = requests.post(self.token_url, data=data)
        response.raise_for_status()
        
        return response.json()
    
    def refresh_token(self, refresh_token: str) -> Dict[str, Any]:
        """
        Refresh access token using refresh token.
        
        Args:
            refresh_token: Valid refresh token
            
        Returns:
            Dict containing new tokens and metadata
        """
        data = {
            'grant_type': 'refresh_token',
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'refresh_token': refresh_token
        }
        
        response = requests.post(self.token_url, data=data)
        response.raise_for_status()
        
        return response.json()
    
    def get_user_info(self, access_token: str) -> Dict[str, Any]:
        """
        Get user information using access token.
        
        Args:
            access_token: Valid access token
            
        Returns:
            Dict containing user information
        """
        headers = {'Authorization': f'Bearer {access_token}'}
        response = requests.get(self.userinfo_url, headers=headers)
        response.raise_for_status()
        
        return response.json()
    
    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Verify and decode JWT token.
        
        Args:
            token: JWT token to verify
            
        Returns:
            Decoded token payload if valid, None otherwise
        """
        try:
            # Get public keys if not cached
            if not self._public_keys:
                self._load_public_keys()
            
            # Decode header to get key ID
            header = jwt.get_unverified_header(token)
            key_id = header.get('kid')
            
            if key_id not in self._public_keys:
                # Refresh keys and try again
                self._load_public_keys()
                if key_id not in self._public_keys:
                    return None
            
            # Verify token
            public_key = self._public_keys[key_id]
            payload = jwt.decode(
                token,
                public_key,
                algorithms=['RS256'],
                audience=self.client_id,
                issuer=self.base_url
            )
            
            return payload
            
        except jwt.InvalidTokenError:
            return None
    
    def _load_public_keys(self):
        """Load public keys from Keycloak."""
        response = requests.get(self.certs_url)
        response.raise_for_status()
        
        jwks = response.json()
        self._public_keys = {}
        
        for key in jwks['keys']:
            self._public_keys[key['kid']] = jwt.algorithms.RSAAlgorithm.from_jwk(key)


# FastAPI middleware example
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()
keycloak_auth = KeycloakAuth()


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    FastAPI dependency to get current authenticated user.
    
    Args:
        credentials: HTTP Bearer token from request
        
    Returns:
        User information from token
        
    Raises:
        HTTPException: If token is invalid or expired
    """
    token = credentials.credentials
    payload = keycloak_auth.verify_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return payload


def require_role(required_role: str):
    """
    FastAPI dependency factory to require specific role.
    
    Args:
        required_role: Role name that user must have
        
    Returns:
        FastAPI dependency function
    """
    def check_role(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
        user_roles = current_user.get('realm_access', {}).get('roles', [])
        
        if required_role not in user_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Required role '{required_role}' not found"
            )
        
        return current_user
    
    return check_role


# Usage example
if __name__ == "__main__":
    # Example usage
    auth = KeycloakAuth()
    
    # Get client credentials token
    token_response = auth.get_client_credentials_token()
    access_token = token_response['access_token']
    
    # Verify token
    payload = auth.verify_token(access_token)
    print(f"Token payload: {payload}")