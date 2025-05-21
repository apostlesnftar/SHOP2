import { StrictMode, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import { initializeAuth } from './store/auth-store';

// Setup function to initialize auth state
const AppWithInitialization = () => {
  useEffect(() => {
    initializeAuth();
  }, []);

  return <App />;
};

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppWithInitialization />
  </StrictMode>
);