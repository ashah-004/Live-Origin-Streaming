import os
import sys
import time
import redis
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from google.cloud import storage

BUCKET_NAME = "live-streaming-segments" 
REDIS_HOST = "redis-store-master.redis-ns.svc.cluster.local"
CASSANDRA_HOST = "cassandra-db-0.cassandra-db-headless.cassandra-ns.svc.cluster.local"
CASS_USER = 'cassandra'
CASS_PASS = 'netflix'

print("PYTHON SCRIPT STARTED! Loading libraries...", flush=True)
if len(sys.argv) < 2:
    print("❌ Error: No directory provided.")
    sys.exit(1)

WATCH_DIR = sys.argv[1]
SESSION_ID = sys.argv[2]

print(f"Sync Agent Started.")
print(f"Watching: {WATCH_DIR}")
print(f"Session ID: {SESSION_ID}")

# --- CONNECT TO SERVICES ---
try:
    storage_client = storage.Client()
    bucket = storage_client.bucket(BUCKET_NAME)
    
    # Check if bucket exists/is accessible
    if not bucket.exists():
        print(f"❌ Error: Bucket {BUCKET_NAME} does not exist or permission denied.")

    r = redis.Redis(host=REDIS_HOST, port=6379, db=0)

    r.set("live_stream:active_id", SESSION_ID)

    print(f"Registered Active Stream ID in Redis: {SESSION_ID}")
    
    print("Connecting to Cassandra...")

    auth_provider = PlainTextAuthProvider(username=CASS_USER, password=CASS_PASS)
    cluster = Cluster([CASSANDRA_HOST], auth_provider=auth_provider)
    session = cluster.connect()
    session.set_keyspace('live_streaming')
    
    # Pre-prepare the statement for performance
    insert_stmt = session.prepare("""
        INSERT INTO segments (stream_id, segment_id, created_at, file_path)
        VALUES (?, ?, toTimestamp(now()), ?)
    """)
    print("✅ Connected to all services.")

except Exception as e:
    print(f"❌ critical Startup Error: {e}")
    sys.exit(1)

# processedFiles = set()
# manifest_done = False
# init_audio_done = False
# init_video_done = False

# --- MAIN LOOP ---
while True:
    try:
        # Wait for folder to be created by FFmpeg
        if not os.path.exists(WATCH_DIR):
            time.sleep(1)
            continue

        # Get files and sort them to process in order (video_1, video_2...)
        # files = sorted([f for f in os.listdir(WATCH_DIR)])
        files = os.listdir(WATCH_DIR)

        for filename in files:
            # Skip hidden files or temporary files
            if filename.startswith("."):
                continue
                
            # # Skip files we have already handled (mostly for init.mp4 or manifest.mpd)
            # if filename in processed_files:
            #     continue

            local_path = os.path.join(WATCH_DIR, filename)

            # if filename == "manifest.mpd" and manifest_done:
            #     continue

            # if filename.endswith("init.mp4"):
            #     if "video" in filename and init_video_done:
            #         continue
            #     if "audio" in filename and init_audio_done:
            #         continue

            # --- 1. UPLOAD TO GCS ---
            blob_name = f"{SESSION_ID}/{filename}" # Structure: session_id/video_1.m4s
            public_url = f"https://storage.googleapis.com/{BUCKET_NAME}/{blob_name}"

            try:
                blob = bucket.blob(blob_name)
                if filename == "manifest.mpd":
                    blob.cache_control = "no-cache, max-age=0"
                blob.upload_from_filename(local_path)
                print(f"☁️ Uploaded: {filename}")
            except Exception as e:
                print(f"❌ Upload Failed for {filename}: {e}")
                continue # Skip DB update if upload fails

            # --- 2. UPDATE DATABASE (Only for Video Segments) ---
            if "video_" in filename and ".m4s" in filename:
                try:
                    # Extract number: video_10.m4s -> 10
                    # This logic assumes standard Shaka/FFmpeg naming
                    seg_num = int(filename.split('_')[1].split('.')[0])

                    # Redis: "Latest segment for this session is X"
                    r.set(f"stream:{SESSION_ID}:latest", seg_num)

                    # Cassandra: Permanent Record
                    session.execute(insert_stmt, [str(SESSION_ID), seg_num, public_url])

                    print(f"🚀 Synced Segment {seg_num} to DB")
                except Exception as e:
                    print(f"⚠️ DB Error: {e}")
            
            # --- 3. CLEANUP ---
            # We delete the .m4s files to save space on the pod.
            # We keep manifest.mpd and init.mp4 usually, but add them to processed set so we don't re-upload.
            if filename.endswith(".m4s"):
                try:
                    os.remove(local_path)
                except OSError:
                    pass # File might already be gone
            # elif filename == "manifest.mpd":
            #         manifest_done = True
            #         print("✅ Manifest Locked.")
            # elif filename.endswith("init.mp4"):
            #         if "video" in filename: init_video_done = True
            #         else: init_audio_done = True
            # else:
            #     # If we don't delete it (like init.mp4), remember we processed it
            #     processed_files.add(filename)


        time.sleep(0.5) 

    except Exception as e:
        print(f"❌ Loop Error: {e}")
        time.sleep(5)