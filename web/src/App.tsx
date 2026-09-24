import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AppProvider, useApp } from './context/AppContext';
import { Navbar } from './components/Navbar';
import { AudioPlayerModal } from './components/AudioPlayerModal';
import { MobileSimulatorModal } from './components/MobileSimulatorModal';
import { IncomingCallBanner } from './components/IncomingCallBanner';
import { LiveInCallBar } from './components/LiveInCallBar';
import { PostCallWrapUpModal } from './components/PostCallWrapUpModal';

import Home from './pages/Home';
import Dashboard from './pages/Dashboard';
import Activities from './pages/Activities';
import Leaderboard from './pages/Leaderboard';
import CrmSync from './pages/CrmSync';
import Security from './pages/Security';
import Admin from './pages/Admin';

import './styles/design.css';
import './App.css';

const ToastNotification: React.FC = () => {
  const { toastMessage, clearToast } = useApp();
  if (!toastMessage) return null;

  return (
    <div
      onClick={clearToast}
      style={{
        position: 'fixed',
        bottom: '24px',
        right: '24px',
        zIndex: 200,
        background: 'var(--bg-glass-elevated)',
        backdropFilter: 'blur(16px)',
        WebkitBackdropFilter: 'blur(16px)',
        border: '1px solid var(--border-highlight)',
        padding: '0.85rem 1.4rem',
        borderRadius: 'var(--radius-lg)',
        boxShadow: '0 20px 40px rgba(0,0,0,0.6), 0 0 30px var(--primary-glow)',
        color: 'var(--text-main)',
        fontSize: '0.9rem',
        fontWeight: 600,
        display: 'flex',
        alignItems: 'center',
        gap: '0.75rem',
        cursor: 'pointer',
        animation: 'slideUp 0.3s ease-out'
      }}
    >
      <span>{toastMessage}</span>
    </div>
  );
};

function MainLayout() {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Navbar />

      <main style={{ flex: 1 }}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/activities" element={<Activities />} />
          <Route path="/leaderboard" element={<Leaderboard />} />
          <Route path="/crm-sync" element={<CrmSync />} />
          <Route path="/security" element={<Security />} />
          <Route path="/admin" element={<Admin />} />
        </Routes>
      </main>

      <footer style={{
        marginTop: 'auto',
        borderTop: '1px solid var(--border-subtle)',
        padding: '2rem 1.5rem',
        textAlign: 'center',
        fontSize: '0.82rem',
        color: 'var(--text-dim)',
        display: 'flex',
        flexDirection: 'column',
        gap: '0.5rem',
        alignItems: 'center'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontWeight: 700, color: 'var(--text-main)' }}>RingVia360 Enterprise</span>
          <span>•</span>
          <span>Automated Call & WhatsApp Telemetry</span>
          <span>•</span>
          <span style={{ color: 'var(--accent-emerald)' }}>E2EE Active</span>
        </div>
        <div>
          Next-Generation Sales Activity Tracking Platform replacing manual data entry with zero-click background sync.
        </div>
      </footer>

      {/* Global Interactive Modals & Telephony Overlays */}
      <IncomingCallBanner />
      <LiveInCallBar />
      <PostCallWrapUpModal />
      <AudioPlayerModal />
      <MobileSimulatorModal />
      <ToastNotification />
    </div>
  );
}

function App() {
  return (
    <AppProvider>
      <BrowserRouter>
        <MainLayout />
      </BrowserRouter>
    </AppProvider>
  );
}

export default App;
