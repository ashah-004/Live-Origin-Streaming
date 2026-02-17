#!/bin/bash
set -e

# --- CONFIGURATION ---
SESSION_ID=$(date +%s)
BASE_DIR="/data/segments"
OUTPUT_DIR="$BASE_DIR/$SESSION_ID"
VIDEO_PIPE="/tmp/video_pipe_$SESSION_ID"
AUDIO_PIPE="/tmp/audio_pipe_$SESSION_ID"

# 1. Setup Directories and Pipes
mkdir -p "$OUTPUT_DIR"
# Create named pipes (First In, First Out)
mkfifo "$VIDEO_PIPE"
mkfifo "$AUDIO_PIPE"

echo "🚀 Starting Stream Session: $SESSION_ID"
echo "📂 Output: $OUTPUT_DIR"

# 2. Start Sync Agent (Background)
echo "☁️ Starting Sync Agent..."
python3 -u sync.py "$OUTPUT_DIR" "$SESSION_ID"& 
PID_SYNC=$!

# 3. Start Shaka Packager (Background)
# We start this BEFORE FFmpeg so it is ready to catch the data coming out of the pipes.
echo "🎬 Starting FFmpeg Encoding..."
ffmpeg -re -stream_loop -1 -i "input.mp4" \
    -map 0:v:0 -c:v libx264 -profile:v main -sc_threshold 0 \
    -r 30 -g 60 -keyint_min 60 \
    -b:v 1000k -maxrate 1000k -bufsize 2000k -s 1280x720 \
    -f mpegts -y "$VIDEO_PIPE" \
    -map 0:a:0 -c:a aac -b:a 128k -ac 2 \
    -f mpegts -y "$AUDIO_PIPE" &
PID_FFMPEG=$!


echo "📦 Starting Packager..."
packager \
  "input=$VIDEO_PIPE,stream=video,init_segment=$OUTPUT_DIR/video_init.mp4,segment_template=$OUTPUT_DIR/video_\$Number\$.m4s" \
  "input=$AUDIO_PIPE,stream=audio,init_segment=$OUTPUT_DIR/audio_init.mp4,segment_template=$OUTPUT_DIR/audio_\$Number\$.m4s" \
  --mpd_output "$OUTPUT_DIR/manifest.mpd" \
  --segment_duration 2 \
  --time_shift_buffer_depth 60 \
  --preserved_segments_outside_live_window 10 &
PID_PACKAGER=$!

# 4. Start FFmpeg (The Engine)
# We map video to pipe 1 and audio to pipe 2.


echo "✅ All processes started."
echo "   - Sync PID: $PID_SYNC"
echo "   - Packager PID: $PID_PACKAGER"
echo "   - FFmpeg PID: $PID_FFMPEG"

# 5. Wait for exit
# We wait for FFmpeg. If it crashes, we kill everything else.
wait $PID_FFMPEG

# 6. Cleanup
echo "⚠️ Stream stopped. Cleaning up..."
kill $PID_PACKAGER $PID_SYNC 2>/dev/null || true
rm -f "$VIDEO_PIPE" "$AUDIO_PIPE"
echo "👋 Done."