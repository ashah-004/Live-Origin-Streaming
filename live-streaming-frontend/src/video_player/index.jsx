import React, {useRef, useEffect} from "react";
import shaka from 'shaka-player/dist/shaka-player.ui.js';
import 'shaka-player/dist/controls.css';

const VideoPlayer = ({manifestUrl}) => {

    const videoRef = useRef(null);
    const containerRef = useRef(null);
    const playerRef = useRef(null);

    useEffect(() => {
        let player;
        let ui;

        const initPlayer = async() => {
            if(!videoRef.current || !containerRef.current) return;

            shaka.polyfill.installAll();

            if(!shaka.Player.isBrowserSupported()){
                console.error('Browser not supported by shaka player.');
                return;
            }


            player = new shaka.Player();
            await player.attach(videoRef.current)
            playerRef.current = player;

            const ui = new shaka.ui.Overlay(player, containerRef.current, videoRef.current);

            ui.configure({
                'controlPanelElements': ['play_pause', 'time_and_duration', 'spacer', 'mute', 'fullscreen', 'overflow_menu']
            });

            player.addEventListener('error', (event) => {
                if (event.detail.code === 7002) return;
                console.error('Shaka Player Error Code:', event.detail.code, event.detail);
            });

            try{
                console.log("Loading Manifest:", manifestUrl);
                await player.load(manifestUrl);
                console.log('stream loaded successfully!');
            } catch (error) {
                console.error('Error loading stream:', error);
            }
        };

        if(manifestUrl){
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
                style={{width: '100%', height: '100%'}}
                poster="https://www.google.com/imgres?q=loading%20&imgurl=https%3A%2F%2Fimg.freepik.com%2Fpremium-vector%2Fvector-loading-different-round-icon_635054-349.jpg%3Fsemt%3Dais_user_personalization%26w%3D740%26q%3D80&imgrefurl=https%3A%2F%2Fwww.freepik.com%2Ffree-photos-vectors%2Floading-line&docid=JwSRGt2SfLIWPM&tbnid=EqdcnPdg6YxR1M&vet=12ahUKEwiT-M_LxNKSAxXbEDQIHZJ6NmEQnPAOegQIcBAB..i&w=740&h=740&hcb=2&ved=2ahUKEwiT-M_LxNKSAxXbEDQIHZJ6NmEQnPAOegQIcBAB"
                autoPlay
                muted
            />
        </div>
    );
}

export default VideoPlayer