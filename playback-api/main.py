from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import redis
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

REDIS_HOST = os.getenv("REDIS_HOST", "redis-store-master.redis-ns.svc.cluster.local")
BUCKET_NAME = "live-streaming-segments"

try:
    r = redis.Redis(host=REDIS_HOST, port=6379, db=0)
    r.ping()
    print(f"connected to redis at {REDIS_HOST}")
except Exception as e:
    print(f"redis connection failed: {e}")

@app.get("/")
def healthCheck():
    return {"status": "playback API is running"}

@app.get("/play")
def get_live_stream():
# check redis and get latest session, build manifest url, give ot to frontend for playing
    try:
        active_id = r.get("live_stream:active_id")

        if not active_id:
            raise HTTPException(status_code=404, detail="No active live stream found.")
        
        session_id = active_id.decode("utf-8")

        manifest_url = f"https://storage.googleapis.com/{BUCKET_NAME}/{session_id}/manifest.mpd"

        return {
            "session_id": session_id,
            "url": manifest_url,
            "status": "live"
        }
    
    except redis.RedisError as e:
        raise HTTPException(status_code=500, detail=f"database error: {str(e)}")