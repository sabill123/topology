"""
Topology Backend API
"""
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn

from app.routes import auth, users, friends, chat, video_call, store, filters
from app.websocket_endpoints import websocket_endpoint
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager

# Lifespan manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("Starting up...")
    # Initialize Google Sheets connection
    GoogleSheetsManager.initialize()
    # Initialize Redis connection
    await RedisManager.initialize()
    
    yield
    
    # Shutdown
    print("Shutting down...")
    await RedisManager.close()

# Create FastAPI app
app = FastAPI(
    title="Topology API",
    description="Backend API for Topology video chat application",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Auth"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(friends.router, prefix="/api/friends", tags=["Friends"])
app.include_router(chat.router, prefix="/api/chat", tags=["Chat"])
app.include_router(video_call.router, prefix="/api/video", tags=["Video Call"])
app.include_router(store.router, prefix="/api/store", tags=["Store"])
app.include_router(filters.router, prefix="/api/filters", tags=["Filters"])

@app.get("/")
async def root():
    return {"message": "Welcome to Topology API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# WebSocket endpoint
@app.websocket("/ws")
async def websocket_handler(websocket: WebSocket, token: str):
    await websocket_endpoint(websocket, token)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )