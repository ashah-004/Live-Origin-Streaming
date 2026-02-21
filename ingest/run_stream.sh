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
mkfifo "$VIDEO_PIPE" || true
mkfifo "$AUDIO_PIPE" || true

echo "🚀 Starting Stream Session: $SESSION_ID"
echo "📂 Output: $OUTPUT_DIR"

# 2. Start Sync Agent (Background)
echo "☁️ Starting Sync Agent..."
python3 -u sync.py "$OUTPUT_DIR" "$SESSION_ID" &
PID_SYNC=$!

# 3. Start Shaka Packager (Background)
echo "📦 Starting Packager..."

packager \
  "input=$VIDEO_PIPE,stream=video,init_segment=$OUTPUT_DIR/video_init.mp4,segment_template=$OUTPUT_DIR/video_\$Number\$.m4s" \
  "input=$AUDIO_PIPE,stream=audio,init_segment=$OUTPUT_DIR/audio_init.mp4,segment_template=$OUTPUT_DIR/audio_\$Number\$.m4s" \
    --mpd_output "$OUTPUT_DIR/manifest.mpd" \
    --segment_duration 2 \
    --low_latency_dash_mode=true \
    --minimum_update_period 5 \
    --suggested_presentation_delay 5 \
    --time_shift_buffer_depth 120 \
    --preserved_segments_outside_live_window 30 \
    --utc_timings "urn:mpeg:dash:utc:http-xsdate:2014=https://time.akamai.com/?iso" \
  > /tmp/packager_$SESSION_ID.log 2>&1 &
PID_PACKAGER=$!

# 4. Start FFmpeg (Engine)
echo "🎬 Starting FFmpeg Encoding..."

ffmpeg -re -stream_loop -1 -fflags +genpts -i "input.mp4" \
  -use_wallclock_as_timestamps 1 \
  -map 0:v:0 -c:v libx264 -preset veryfast -tune zerolatency \
  -r 30 -g 60 -keyint_min 60 -sc_threshold 0 \
  -b:v 1200k -maxrate 1200k -bufsize 3600k \
  -vsync 1 \
  -muxdelay 0 -muxpreload 0 \
  -f mp4 -movflags +frag_keyframe+empty_moov+default_base_moof \
  -y "$VIDEO_PIPE" \
  -map 0:a:0 -c:a aac -b:a 128k -ac 2 \
  -f mp4 -movflags +frag_keyframe+empty_moov+default_base_moof\
  -y "$AUDIO_PIPE" &
PID_FFMPEG=$!

echo "✅ All processes started."
echo "   - Sync PID: $PID_SYNC"
echo "   - Packager PID: $PID_PACKAGER"
echo "   - FFmpeg PID: $PID_FFMPEG"

# 5. Wait for FFmpeg
wait $PID_FFMPEG || true

# 6. Cleanup
echo "⚠️ Stream stopped. Cleaning up..."
kill $PID_PACKAGER $PID_SYNC 2>/dev/null || true
rm -f "$VIDEO_PIPE" "$AUDIO_PIPE"
echo "👋 Done."
