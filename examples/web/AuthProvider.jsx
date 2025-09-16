import React, { createContext, useContext, useEffect, useState } from 'react';
import CareTwinAuth from './caretwin-auth';

const AuthContext = createContext();

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within AuthProvider');
    }
    return context;
};

export const AuthProvider = ({ children }) => {
    const [auth] = useState(new CareTwinAuth());
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);
    const [isAuthenticated, setIsAuthenticated] = useState(false);

    useEffect(() => {
        initializeAuth();
    }, []);

    const initializeAuth = async () => {
        try {
            // Check if we have tokens
            if (auth.accessToken) {
                if (auth.isAuthenticated()) {
                    await auth.loadUserInfo();
                    setUser(auth.user);
                    setIsAuthenticated(true);
                } else if (auth.refreshToken) {
                    // Try to refresh token
                    try {
                        await auth.refreshAccessToken();
                        await auth.loadUserInfo();
                        setUser(auth.user);
                        setIsAuthenticated(true);
                    } catch (error) {
                        console.error('Token refresh failed:', error);
                        auth.logout(false);
                    }
                }
            }

            // Check for OAuth callback
            const urlParams = new URLSearchParams(window.location.search);
            const code = urlParams.get('code');
            const state = urlParams.get('state');

            if (code) {
                const result = await auth.handleCallback(code, state);
                if (result.success) {
                    setUser(result.user);
                    setIsAuthenticated(true);
                    // Clean up URL
                    window.history.replaceState({}, document.title, window.location.pathname);
                } else {
                    console.error('Login failed:', result.error);
                }
            }
        } catch (error) {
            console.error('Auth initialization failed:', error);
        } finally {
            setLoading(false);
        }
    };

    const login = () => {
        auth.login();
    };

    const logout = () => {
        auth.logout();
        setUser(null);
        setIsAuthenticated(false);
    };

    const hasRole = (role) => {
        return auth.hasRole(role);
    };

    const apiRequest = async (url, options = {}) => {
        return auth.apiRequest(url, options);
    };

    const value = {
        user,
        isAuthenticated,
        loading,
        login,
        logout,
        hasRole,
        apiRequest,
        auth
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
};

// Higher-order component for protected routes
export const withAuth = (Component) => {
    return (props) => {
        const { isAuthenticated, loading } = useAuth();

        if (loading) {
            return <div className="loading">Loading...</div>;
        }

        if (!isAuthenticated) {
            return <LoginRequired />;
        }

        return <Component {...props} />;
    };
};

// Component to show when authentication is required
const LoginRequired = () => {
    const { login } = useAuth();

    return (
        <div className="login-required">
            <h2>Authentication Required</h2>
            <p>Please log in to access this content.</p>
            <button onClick={login} className="btn btn-primary">
                Log In
            </button>
        </div>
    );
};

// Higher-order component for role-based access
export const withRole = (Component, requiredRole) => {
    return (props) => {
        const { isAuthenticated, hasRole, loading } = useAuth();

        if (loading) {
            return <div className="loading">Loading...</div>;
        }

        if (!isAuthenticated) {
            return <LoginRequired />;
        }

        if (!hasRole(requiredRole)) {
            return (
                <div className="access-denied">
                    <h2>Access Denied</h2>
                    <p>You don't have permission to access this content.</p>
                    <p>Required role: {requiredRole}</p>
                </div>
            );
        }

        return <Component {...props} />;
    };
};