/**
 * CareTwin Keycloak Web Integration
 * 
 * This module provides authentication utilities for the web application viewer
 * to integrate with Keycloak for user authentication and authorization.
 */

class CareTwinAuth {
    constructor(config = {}) {
        this.keycloakUrl = config.keycloakUrl || process.env.REACT_APP_KEYCLOAK_URL || 'http://localhost:8080';
        this.realm = config.realm || process.env.REACT_APP_KEYCLOAK_REALM || 'caretwin';
        this.clientId = config.clientId || process.env.REACT_APP_WEB_CLIENT_ID || 'lidar-web-viewer';
        this.redirectUri = config.redirectUri || `${window.location.origin}/auth/callback`;
        
        this.baseUrl = `${this.keycloakUrl}/realms/${this.realm}`;
        this.authUrl = `${this.baseUrl}/protocol/openid-connect/auth`;
        this.tokenUrl = `${this.baseUrl}/protocol/openid-connect/token`;
        this.logoutUrl = `${this.baseUrl}/protocol/openid-connect/logout`;
        this.userInfoUrl = `${this.baseUrl}/protocol/openid-connect/userinfo`;
        
        this.accessToken = localStorage.getItem('caretwin_access_token');
        this.refreshToken = localStorage.getItem('caretwin_refresh_token');
        this.user = null;
        
        // Auto-refresh token before expiry
        this.setupTokenRefresh();
    }
    
    /**
     * Generate authorization URL for OAuth flow
     */
    getAuthorizationUrl(state = null) {
        const params = new URLSearchParams({
            client_id: this.clientId,
            redirect_uri: this.redirectUri,
            response_type: 'code',
            scope: 'openid profile email',
            state: state || this.generateState()
        });
        
        return `${this.authUrl}?${params.toString()}`;
    }
    
    /**
     * Redirect to Keycloak login
     */
    login(state = null) {
        const authUrl = this.getAuthorizationUrl(state);
        window.location.href = authUrl;
    }
    
    /**
     * Handle OAuth callback and exchange code for tokens
     */
    async handleCallback(code, state = null) {
        try {
            const tokenData = await this.exchangeCodeForTokens(code);
            
            this.setTokens(tokenData.access_token, tokenData.refresh_token);
            await this.loadUserInfo();
            
            return { success: true, user: this.user };
        } catch (error) {
            console.error('Login callback failed:', error);
            return { success: false, error: error.message };
        }
    }
    
    /**
     * Exchange authorization code for tokens
     */
    async exchangeCodeForTokens(code) {
        const params = new URLSearchParams({
            grant_type: 'authorization_code',
            client_id: this.clientId,
            code: code,
            redirect_uri: this.redirectUri
        });
        
        const response = await fetch(this.tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params.toString()
        });
        
        if (!response.ok) {
            throw new Error(`Token exchange failed: ${response.statusText}`);
        }
        
        return await response.json();
    }
    
    /**
     * Refresh access token using refresh token
     */
    async refreshAccessToken() {
        if (!this.refreshToken) {
            throw new Error('No refresh token available');
        }
        
        const params = new URLSearchParams({
            grant_type: 'refresh_token',
            client_id: this.clientId,
            refresh_token: this.refreshToken
        });
        
        const response = await fetch(this.tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params.toString()
        });
        
        if (!response.ok) {
            this.logout();
            throw new Error(`Token refresh failed: ${response.statusText}`);
        }
        
        const tokenData = await response.json();
        this.setTokens(tokenData.access_token, tokenData.refresh_token);
        
        return tokenData;
    }
    
    /**
     * Load user information from Keycloak
     */
    async loadUserInfo() {
        if (!this.accessToken) {
            throw new Error('No access token available');
        }
        
        const response = await fetch(this.userInfoUrl, {
            headers: {
                'Authorization': `Bearer ${this.accessToken}`
            }
        });
        
        if (!response.ok) {
            throw new Error(`Failed to load user info: ${response.statusText}`);
        }
        
        this.user = await response.json();
        return this.user;
    }
    
    /**
     * Logout user and clear tokens
     */
    logout(redirectToLogin = true) {
        const idToken = localStorage.getItem('caretwin_id_token');
        
        // Clear local storage
        localStorage.removeItem('caretwin_access_token');
        localStorage.removeItem('caretwin_refresh_token');
        localStorage.removeItem('caretwin_id_token');
        
        this.accessToken = null;
        this.refreshToken = null;
        this.user = null;
        
        if (redirectToLogin) {
            const logoutParams = new URLSearchParams({
                client_id: this.clientId,
                post_logout_redirect_uri: window.location.origin
            });
            
            if (idToken) {
                logoutParams.append('id_token_hint', idToken);
            }
            
            window.location.href = `${this.logoutUrl}?${logoutParams.toString()}`;
        }
    }
    
    /**
     * Check if user is authenticated
     */
    isAuthenticated() {
        return !!this.accessToken && !this.isTokenExpired();
    }
    
    /**
     * Check if access token is expired
     */
    isTokenExpired() {
        if (!this.accessToken) return true;
        
        try {
            const payload = JSON.parse(atob(this.accessToken.split('.')[1]));
            return Date.now() >= payload.exp * 1000;
        } catch {
            return true;
        }
    }
    
    /**
     * Get user roles
     */
    getUserRoles() {
        if (!this.user) return [];
        return this.user.realm_access?.roles || [];
    }
    
    /**
     * Check if user has specific role
     */
    hasRole(role) {
        return this.getUserRoles().includes(role);
    }
    
    /**
     * Get authorization header for API requests
     */
    getAuthHeader() {
        return this.accessToken ? { 'Authorization': `Bearer ${this.accessToken}` } : {};
    }
    
    /**
     * Make authenticated API request
     */
    async apiRequest(url, options = {}) {
        if (!this.isAuthenticated()) {
            throw new Error('User not authenticated');
        }
        
        const headers = {
            ...options.headers,
            ...this.getAuthHeader()
        };
        
        let response = await fetch(url, { ...options, headers });
        
        // If token expired, try to refresh and retry
        if (response.status === 401 && this.refreshToken) {
            try {
                await this.refreshAccessToken();
                headers.Authorization = `Bearer ${this.accessToken}`;
                response = await fetch(url, { ...options, headers });
            } catch (error) {
                this.logout();
                throw error;
            }
        }
        
        return response;
    }
    
    /**
     * Set tokens in local storage
     */
    setTokens(accessToken, refreshToken, idToken = null) {
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        
        localStorage.setItem('caretwin_access_token', accessToken);
        if (refreshToken) {
            localStorage.setItem('caretwin_refresh_token', refreshToken);
        }
        if (idToken) {
            localStorage.setItem('caretwin_id_token', idToken);
        }
        
        this.setupTokenRefresh();
    }
    
    /**
     * Setup automatic token refresh
     */
    setupTokenRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
        
        if (!this.accessToken || !this.refreshToken) return;
        
        try {
            const payload = JSON.parse(atob(this.accessToken.split('.')[1]));
            const expiresIn = (payload.exp * 1000) - Date.now();
            const refreshTime = Math.max(expiresIn - 60000, 30000); // Refresh 1 min before expiry, min 30s
            
            this.refreshInterval = setTimeout(async () => {
                try {
                    await this.refreshAccessToken();
                } catch (error) {
                    console.error('Auto token refresh failed:', error);
                    this.logout();
                }
            }, refreshTime);
        } catch (error) {
            console.error('Failed to setup token refresh:', error);
        }
    }
    
    /**
     * Generate random state for OAuth flow
     */
    generateState() {
        return Math.random().toString(36).substring(2, 15) + 
               Math.random().toString(36).substring(2, 15);
    }
}

export default CareTwinAuth;