import { useState, useEffect } from 'react'
import axios from 'axios';
import VideoPlayer from './video_player/index'
import './App.css'

const API_URL = "http://136.109.193.40/play";

function App() {

  const [streamData, setStreamData] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStream = async() => {
      try{
        console.log("Connecting to backend...");
        const response = await axios.get(API_URL);

        console.log("Backend response: ", response.data);
        setStreamData(response.data);
        setLoading(false);
      } catch (err) {
        console.error("Failed to fetch stream: ", err);
        setError("Stream is offline or backend is unreachable.");
        setLoading(false);
      }
    };

      fetchStream();
  }, [])

  return (
    <div className='app-container'>
      <header>
        <h1>Live Stream</h1>
      </header>

      <main>
        {loading && <div className='status'>Loading Active Stream...</div>}

        {error && <div className='error'>{error}</div>}

        {streamData && (
          <div className='player-wrapper'>
            <div className='stream-info'>
              <span className='badge live'>LIVE</span>
              <span>Session ID : {streamData.session_id}</span>
            </div>

            <VideoPlayer manifestUrl={streamData.url}/>
          </div>
        )}
      </main>
    </div>
  )
}

export default App
