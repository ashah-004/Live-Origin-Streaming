# Base Image: Ubuntu-based FFmpeg (Compatible with Packager)
FROM jrottenberg/ffmpeg:4.4-ubuntu

# Install tools to download the packager
RUN apt-get update && apt-get install -y \
    wget \
    ca-certificates \
    bash \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

ENV CASS_DRIVER_NO_CYTHON=1

RUN pip3 install --no-cache-dir \
    google-cloud-storage \
    redis \
    cassandra-driver

# DOWNLOAD Packager directly from GitHub (Safe & Reliable)
# DOWNLOAD latest Shaka Packager (v2.7.0+)
RUN wget https://github.com/shaka-project/shaka-packager/releases/latest/download/packager-linux-x64 \
    -O /usr/bin/packager && \
    chmod +x /usr/bin/packager

# Make it executable
RUN chmod +x /usr/bin/packager

WORKDIR /app

COPY input.mp4 .
COPY run_stream.sh .
COPY sync.py .
RUN chmod +x run_stream.sh
RUN mkdir -p /data/segments

# Clear entrypoint and run script
ENTRYPOINT []
CMD ["./run_stream.sh"]