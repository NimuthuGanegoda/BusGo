import { useState } from 'react';
import { Mail, Lock, Eye, EyeOff, ArrowRight } from 'lucide-react';
import './Login.css';

export default function Login() {
  const [email,       setEmail]       = useState('');
  const [password,    setPassword]    = useState('');
  const [rememberMe,  setRememberMe]  = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loading,     setLoading]     = useState(false);
  const [error,       setError]       = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) { setError('Please enter email and password.'); return; }
    setError(''); setLoading(true);
    try {
      const res = await fetch('http://localhost:5000/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Login failed');
      if (data.data?.user?.role !== 'admin') throw new Error('Admin accounts only');
      localStorage.setItem('busgo_access_token', data.data.access_token);
      localStorage.setItem('busgo_refresh_token', data.data.refresh_token);
      window.location.href = '/admin/dashboard';
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-left">
        <div className="login-logo-section">
          <div className="orbital-container">
            <div className="orbital-ring orbital-ring-1"></div>
            <div className="orbital-ring orbital-ring-2"></div>
            <div className="orbital-ring orbital-ring-3"></div>
            <div className="orbital-dot orbital-dot-1"></div>
            <div className="orbital-dot orbital-dot-2"></div>
            <div className="orbital-dot orbital-dot-3"></div>
          </div>
          <div className="logo-wrapper">
            <div className="logo-glow"></div>
            <img src="/busgo-logo.jpeg" alt="BUSGO Logo" className="logo-image rotating" />
          </div>
          <div className="brand-text">
            <h1 className="brand-name">A X I S</h1>
            <div className="brand-dot"></div>
            <p className="brand-tagline">A D M I N &nbsp; U S E</p>
          </div>
        </div>
        <div className="login-copyright">
          &copy; 2025 BUSGO AXIS. All rights reserved.
        </div>
      </div>

      <div className="login-right">
        <div className="login-card-wrapper">
          <div className="neon-border">
            <div className="neon-light"></div>
          </div>
          <div className="login-card">
            <div className="card-header">
              <div className="card-logo">
                <img src="/busgo-logo.jpeg" alt="" className="card-logo-img" />
                <span className="card-logo-text">BUSGO AXIS</span>
              </div>
              <h2 className="card-title">Sign In</h2>
            </div>

            {error && (
              <div style={{
                background: 'rgba(239,68,68,0.1)',
                border: '1px solid rgba(239,68,68,0.3)',
                borderRadius: '8px',
                padding: '10px 14px',
                marginBottom: '16px',
                color: '#ef4444',
                fontSize: '13px',
              }}>
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit} className="login-form">
              <div className="form-group">
                <label className="form-label">EMAIL</label>
                <div className="neon-input-wrapper">
                  <div className="neon-input-border">
                    <div className="neon-input-light"></div>
                  </div>
                  <div className="input-inner">
                    <Mail size={18} className="input-icon" />
                    <input
                      type="email"
                      placeholder="admin@busgo.lk"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="form-input"
                      required
                    />
                  </div>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">PASSWORD</label>
                <div className="neon-input-wrapper">
                  <div className="neon-input-border">
                    <div className="neon-input-light"></div>
                  </div>
                  <div className="input-inner">
                    <Lock size={18} className="input-icon" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      placeholder="Enter password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="form-input"
                      required
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                </div>
              </div>

              <div className="form-options">
                <label className="remember-me">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                  />
                  <span className="checkmark"></span>
                  <span>Remember me</span>
                </label>
                <a href="#" className="forgot-link">Forgot password?</a>
              </div>

              <button type="submit" className="signin-btn" disabled={loading}>
                <span>{loading ? 'Signing in...' : 'Sign In'}</span>
                {!loading && <ArrowRight size={20} />}
              </button>
            </form>

            <div className="secured-badge">
              <span className="secured-dot"></span>
              <span>SECURED &middot; ENTERPRISE GRADE</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}