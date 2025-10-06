import React from 'react';
import { useAuth, withAuth, withRole } from './AuthProvider';

// Main App component
function App() {
    return (
        <div className="App">
            <Header />
            <main>
                <PublicComponent />
                <ProtectedComponent />
                <AdminComponent />
            </main>
        </div>
    );
}

// Header with authentication controls
function Header() {
    const { user, isAuthenticated, login, logout } = useAuth();

    return (
        <header className="app-header">
            <div className="header-content">
                <h1>CareTwin LiDAR Viewer</h1>
                <div className="auth-controls">
                    {isAuthenticated ? (
                        <div className="user-info">
                            <span>Welcome, {user?.name || user?.preferred_username}</span>
                            <button onClick={logout} className="btn btn-secondary">
                                Logout
                            </button>
                        </div>
                    ) : (
                        <button onClick={login} className="btn btn-primary">
                            Login
                        </button>
                    )}
                </div>
            </div>
        </header>
    );
}

// Public component (no authentication required)
function PublicComponent() {
    return (
        <section className="public-section">
            <h2>Public Content</h2>
            <p>This content is available to everyone.</p>
        </section>
    );
}

// Protected component (authentication required)
const ProtectedComponent = withAuth(() => {
    const { user, apiRequest } = useAuth();
    const [models, setModels] = React.useState([]);
    const [loading, setLoading] = React.useState(false);

    const loadModels = async () => {
        setLoading(true);
        try {
            const response = await apiRequest('http://localhost:8000/models');
            if (response.ok) {
                const data = await response.json();
                setModels(data.models || []);
            }
        } catch (error) {
            console.error('Failed to load models:', error);
        } finally {
            setLoading(false);
        }
    };

    React.useEffect(() => {
        loadModels();
    }, []);

    return (
        <section className="protected-section">
            <h2>Protected Content</h2>
            <p>Welcome, {user?.name || user?.preferred_username}!</p>
            <p>Your roles: {user?.realm_access?.roles?.join(', ') || 'None'}</p>
            
            <div className="models-section">
                <h3>Available Models</h3>
                {loading ? (
                    <p>Loading models...</p>
                ) : (
                    <ul className="models-list">
                        {models.map(model => (
                            <li key={model.id} className="model-item">
                                <h4>{model.name}</h4>
                                <p>{model.description}</p>
                                <small>Path: {model.file_path}</small>
                            </li>
                        ))}
                    </ul>
                )}
                <button onClick={loadModels} className="btn btn-secondary">
                    Refresh Models
                </button>
            </div>
        </section>
    );
});

// Admin-only component (requires admin role)
const AdminComponent = withRole(() => {
    const { apiRequest } = useAuth();
    const [adminData, setAdminData] = React.useState(null);

    const loadAdminData = async () => {
        try {
            const response = await apiRequest('http://localhost:8000/admin-only');
            if (response.ok) {
                const data = await response.json();
                setAdminData(data);
            }
        } catch (error) {
            console.error('Failed to load admin data:', error);
        }
    };

    React.useEffect(() => {
        loadAdminData();
    }, []);

    return (
        <section className="admin-section">
            <h2>Admin Panel</h2>
            <p>This content is only visible to administrators.</p>
            {adminData && (
                <div className="admin-data">
                    <h3>Admin Data</h3>
                    <pre>{JSON.stringify(adminData, null, 2)}</pre>
                </div>
            )}
        </section>
    );
}, 'admin');

export default App;