"""
FastAPI Example Application with Keycloak Authentication

This example demonstrates how to integrate Keycloak authentication
into a FastAPI application for the 3DGS API Service.
"""

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Any, List
import os

from keycloak_auth import KeycloakAuth, get_current_user, require_role

app = FastAPI(
    title="3DGS API Service",
    description="CareTwin 3D Gaussian Splatting API with Keycloak Authentication",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://your-web-app-domain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class UserProfile(BaseModel):
    sub: str
    email: str
    name: str
    roles: List[str]

class ModelData(BaseModel):
    id: str
    name: str
    description: str
    file_path: str

# Initialize Keycloak auth
keycloak_auth = KeycloakAuth()


@app.get("/")
async def root():
    """Public endpoint - no authentication required."""
    return {"message": "CareTwin 3DGS API Service", "status": "running"}


@app.get("/health")
async def health_check():
    """Health check endpoint - no authentication required."""
    return {"status": "healthy", "service": "3dgs-api"}


@app.get("/protected")
async def protected_endpoint(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Protected endpoint - requires valid authentication."""
    return {
        "message": "Access granted to protected resource",
        "user": current_user.get("preferred_username"),
        "roles": current_user.get("realm_access", {}).get("roles", [])
    }


@app.get("/profile", response_model=UserProfile)
async def get_user_profile(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Get current user profile."""
    return UserProfile(
        sub=current_user.get("sub"),
        email=current_user.get("email"),
        name=current_user.get("name", current_user.get("preferred_username")),
        roles=current_user.get("realm_access", {}).get("roles", [])
    )


@app.get("/admin-only")
async def admin_only_endpoint(current_user: Dict[str, Any] = Depends(require_role("admin"))):
    """Admin-only endpoint - requires admin role."""
    return {
        "message": "Admin access granted",
        "user": current_user.get("preferred_username")
    }


@app.get("/models")
async def list_models(current_user: Dict[str, Any] = Depends(get_current_user)):
    """List available 3D models - requires authentication."""
    # This would typically query a database
    mock_models = [
        ModelData(
            id="model_1",
            name="Sample Building",
            description="3D scan of a sample building",
            file_path="/models/building_001.ply"
        ),
        ModelData(
            id="model_2", 
            name="Interior Room",
            description="Interior room scan",
            file_path="/models/room_001.ply"
        )
    ]
    return {"models": mock_models}


@app.post("/models")
async def create_model(
    model_data: ModelData,
    current_user: Dict[str, Any] = Depends(require_role("api_user"))
):
    """Create new 3D model - requires api_user role."""
    # This would typically save to a database
    return {
        "message": "Model created successfully",
        "model": model_data,
        "created_by": current_user.get("preferred_username")
    }


@app.get("/models/{model_id}")
async def get_model(
    model_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get specific 3D model - requires authentication."""
    # This would typically query a database
    if model_id == "model_1":
        return ModelData(
            id=model_id,
            name="Sample Building",
            description="3D scan of a sample building",
            file_path="/models/building_001.ply"
        )
    else:
        raise HTTPException(status_code=404, detail="Model not found")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        reload=True
    )