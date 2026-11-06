import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/fira-sans/400.css';
import '@fontsource/fira-sans/500.css';
import '@fontsource/fira-sans/600.css';
import '@fontsource/fira-code/500.css';
import './styles.css';
import App from './App';
import { initTheme } from './lib/theme';

initTheme();

// The phone-app sign-in hand-off in index.html owns the page; do not start the web app under it.
if (!(window as unknown as { __basivoHandoff?: boolean }).__basivoHandoff) {
  createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
}
