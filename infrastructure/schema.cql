CREATE KEYSPACE IF NOT EXISTS live_streaming
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};

CREATE TABLE IF NOT EXISTS live_streaming.segments (
    stream_id text,
    segment_id int,
    created_at timestamp,
    file_path text,
    PRIMARY KEY (stream_id, segment_id)
)
WITH CLUSTERING ORDER BY (segment_id DESC);
