import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './app'
import { bootstrap, queryClient } from './lib/api'
import { useSession } from './lib/session'
import './index.css'

void bootstrap()
if ('BroadcastChannel' in window) {
  const channel = new BroadcastChannel('flow-session')
  channel.onmessage = event => { if (event.data === 'logout') { useSession.getState().clear(); queryClient.clear() } }
}
createRoot(document.getElementById('root')!).render(<StrictMode><App/></StrictMode>)
