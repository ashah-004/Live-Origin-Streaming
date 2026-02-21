import React, { useRef, useEffect } from "react";
import shaka from 'shaka-player/dist/shaka-player.ui.js';
import 'shaka-player/dist/controls.css';

const VideoPlayer = ({ manifestUrl }) => {

    const videoRef = useRef(null);
    const containerRef = useRef(null);
    const playerRef = useRef(null);
    const uiref = useRef(null);

    useEffect(() => {
        let player;
        let ui;

        const initPlayer = async () => {
            if (!videoRef.current || !containerRef.current) return;

            shaka.polyfill.installAll();

            if (!shaka.Player.isBrowserSupported()) {
                console.error('Browser not supported by shaka player.');
                return;
            }


            player = new shaka.Player();
            await player.attach(videoRef.current)
            playerRef.current = player;

            const ui = new shaka.ui.Overlay(player, containerRef.current, videoRef.current);
            uiref.current = ui;

            ui.configure({
                'controlPanelElements': ['play_pause', 'time_and_duration', 'spacer', 'mute', 'fullscreen', 'overflow_menu']
            });


            player.configurationForLowLatency({
            streaming: {
                lowLatencyMode: true,

                // SAFETY VALUES
                rebufferingGoal: 0.5,          // small but safe
                bufferingGoal: 2,              // stay slightly behind live edge
                bufferBehind: 30,
                inaccurateManifestTolerance: 0, // strict for LL-DASH
                updateIntervalSeconds: 0.1,    // MPD refresh every 250ms
                segmentPrefetchLimit: 1,        // fetch partial segments early
                maxDisabledTime: 1,             // LL-DASH default
                retryParameters: {
                    maxAttempts: 3,
                    baseDelay: 1000,
                    backoffFactor: 2,
                }
            },

            manifest: {
                dash: {
                clockSyncUri: "https://time.akamai.com/?iso",
                autoCorrectDrift: true,       // IMPORTANT for stability
                ignoreMinBufferTime: true,
                },
            },
            });
            player.addEventListener('error', (event) => {
                if (event.detail.code === 7002) return;
                console.error('Shaka Player Error Code:', event.detail.code, event.detail);
            });

            try {
                console.log("Loading Manifest:", manifestUrl);
                await player.load(manifestUrl);
                console.log('stream loaded successfully!');
            } catch (error) {
                console.error('Error loading stream:', error);
            }
        };

        if (manifestUrl) {
            initPlayer();
        }

        return () => {
            console.log("Cleaning up player...");
            if (ui) {
                ui.destroy(); // Destroy UI first
            }
            if (player) {
                player.destroy(); // Then destroy player
            }
            uiref.current = null;
            playerRef.current = null;
        };

    }, [manifestUrl])

    return (
        <div
            ref={containerRef}
            style={{
                maxWidth: '800px',
                margin: '0 aut0',
                boxShadow: '0 0 20px rgba(0, 0, 0, 0.5)'
            }}
        >
            <video
                ref={videoRef}
                style={{ width: '100%', height: '100%' }}
                autoPlay
                muted
                playsInline
            />
        </div>
    );
}

export default VideoPlayer