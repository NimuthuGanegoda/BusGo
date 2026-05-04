import { useState, useEffect, useRef } from 'react';
import { Eye, EyeOff } from 'lucide-react';
import anime from 'animejs';
import './Login.css';
import busgoLogo from '../assets/busgo-logo-new.jpeg';
import busSvgRaw from '../assets/bus-animation.svg?raw';

type ToastType = 'success' | 'error' | 'warning' | 'info';
interface ToastData { id: number; type: ToastType; title: string; message: string; }

const toastConfig: Record<ToastType, {
  bg: string; border: string; glow: string; text: string; icon: string;
}> = {
  success: {
    bg: 'rgba(7,149,66,0.12)', border: 'rgba(36,241,6,0.46)',
    glow: '#259c08', text: '#0ad406', icon: '✓',
  },
  error: {
    bg: 'rgba(220,17,1,0.16)', border: 'rgba(241,6,6,0.81)',
    glow: '#ff0303', text: '#ff0303', icon: '✕',
  },
  warning: {
    bg: 'rgba(220,128,1,0.16)', border: 'rgba(241,142,6,0.81)',
    glow: '#ffb103', text: '#ffb103', icon: '⚠',
  },
  info: {
    bg: 'rgba(7,73,149,0.12)', border: 'rgba(6,44,241,0.46)',
    glow: '#0396ff', text: '#0396ff', icon: 'ℹ',
  },
};

function NeonToast({ toast, onClose }: { toast: ToastData; onClose: () => void }) {
  const cfg = toastConfig[toast.type];
  useEffect(() => {
    const timer = setTimeout(onClose, 4000);
    return () => clearTimeout(timer);
  }, [onClose]);

  return (
    <div
      style={{
        background: cfg.bg,
        border: `1px solid ${cfg.border}`,
        boxShadow: `0 0 12px ${cfg.glow}40`,
        borderRadius: '10px',
        padding: '14px 16px',
        marginBottom: '10px',
        display: 'flex',
        alignItems: 'flex-start',
        gap: '12px',
        animation: 'slideDown 0.4s ease-out',
        cursor: 'pointer',
        position: 'relative',
      }}
      onClick={onClose}
    >
      <div style={{
        width: '3px', height: '40px', background: cfg.text,
        borderRadius: '2px', boxShadow: `0 0 6px ${cfg.text}`,
        flexShrink: 0,
      }} />
      <div style={{
        fontSize: '18px', color: cfg.text,
        textShadow: `0 0 8px ${cfg.glow}80`,
        flexShrink: 0, marginTop: '2px',
      }}>
        {cfg.icon}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{
          color: cfg.text, fontWeight: 700, fontSize: '14px',
          textShadow: '1px 1px 2px rgba(0,0,0,0.8)',
        }}>
          {toast.title}
        </div>
        <div style={{
          color: cfg.text, opacity: 0.8, fontSize: '12px', marginTop: '2px',
          textShadow: '1px 1px 2px rgba(0,0,0,0.6)',
        }}>
          {toast.message}
        </div>
      </div>
      <div style={{
        color: cfg.text, opacity: 0.6, cursor: 'pointer',
        fontSize: '14px', flexShrink: 0,
      }}>
        ✕
      </div>
    </div>
  );
}

export default function Login() {
  const [email,        setEmail]        = useState('');
  const [password,     setPassword]     = useState('');
  const [rememberMe,   setRememberMe]   = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loading,      setLoading]      = useState(false);
  const [toasts,       setToasts]       = useState<ToastData[]>([]);

  const [splashVisible, setSplashVisible] = useState(true);
  const [splashFading,  setSplashFading]  = useState(false);
  const splashRef = useRef<HTMLDivElement>(null);
  const busRef    = useRef<HTMLDivElement>(null);
  let toastId = useRef(0);

  const addToast = (type: ToastType, title: string, message: string) => {
    const id = ++toastId.current;
    setToasts(prev => [...prev, { id, type, title, message }]);
  };
  const removeToast = (id: number) => {
    setToasts(prev => prev.filter(t => t.id !== id));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      addToast('warning', 'Missing Fields', 'Please enter email and password.');
      return;
    }
    setLoading(true);

    const maxRetries = 2;
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const res = await fetch('https://busgo-production.up.railway.app/api/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password }),
        });
        const data = await res.json();

        if (res.status === 429) {
          setLoading(false);
          addToast('warning', 'Slow Down', 'Too many attempts. Please wait a moment and try again.');
          return;
        }

        if (!res.ok) {
          setLoading(false);
          addToast('error', 'Login Failed', 'Invalid email or password. Please try again.');
          return;
        }

        // ── Role restriction — admin and developer allowed ──────────────────
        const allowedRoles = ['admin', 'developer'];
        if (!allowedRoles.includes(data.data?.user?.role)) {
          setLoading(false);
          addToast('error', 'Access Denied', 'This account is not authorized to access this panel.');
          return;
        }

        localStorage.setItem('busgo_access_token',  data.data.access_token);
        localStorage.setItem('busgo_refresh_token', data.data.refresh_token);

        addToast('success', 'Welcome!', 'Logged in successfully. Redirecting...');
        setTimeout(() => { window.location.href = '/admin/dashboard'; }, 1000);
        return;

      } catch (err: any) {
        if (attempt < maxRetries) {
          await new Promise(r => setTimeout(r, 800));
          continue;
        }
        setLoading(false);
        addToast('warning', 'Connection Error', 'Could not reach the server. Check your connection.');
        return;
      }
    }
    setLoading(false);
  };

  useEffect(() => {
    const el = splashRef.current;
    if (!el) return;

    const setDashoffset = function(pathEl: SVGGeometryElement) {
      const l = pathEl.getTotalLength();
      pathEl.setAttribute('stroke-dasharray', String(l));
      return [l, 0];
    };

    el.classList.add('ready');

    const letters = anime({
      targets: '#splash-lines path',
      strokeDashoffset: {
        value: function(pathEl: any) { return setDashoffset(pathEl); },
        duration: 700,
        easing: 'easeOutQuad',
      },
      transform: ['translate(0 128)', 'translate(0 0)'],
      delay: function(_el: any, i: number) { return 600 + (i * 140); },
      duration: 1400,
    });

    const dotDrop = anime({
      targets: '#splash-dot',
      transform: ['translate(0 -300) scale(1 3)', 'translate(0 0) scale(1 1)'],
      opacity: [0, 1],
      duration: 600,
      easing: 'easeOutBounce',
      delay: (letters as any).duration - 200,
    });

    const fills = anime({
      targets: '#splash-fills *',
      opacity: [0, 1],
      delay: function(_el: any, i: number, l: number) {
        const mid = l / 2;
        const dist = Math.abs(i - mid);
        return ((letters as any).duration - 200) + (dist * 40);
      },
      duration: 500,
      easing: 'linear',
    });

    anime({
      targets: '.splash-subtitle',
      opacity: [0, 1],
      translateY: [20, 0],
      duration: 500,
      easing: 'easeOutQuad',
      delay: (fills as any).duration + 200,
    });

    const totalDuration = (fills as any).duration + 1200;
    setTimeout(() => {
      setSplashFading(true);
      setTimeout(() => setSplashVisible(false), 1000);
    }, totalDuration);

  }, []);

  useEffect(() => {
    if (splashVisible) return;
    const bus = busRef.current;
    if (!bus) return;

    const svg = bus.querySelector('#bus-animation') as SVGElement;
    if (!svg) return;
    svg.style.visibility = 'visible';

    bus.querySelectorAll('#rotate-left, #rotate-right').forEach(g => {
      (g as SVGElement).style.transformBox = 'fill-box';
      (g as SVGElement).style.transformOrigin = 'center';
    });
    const floor = bus.querySelector('#floor') as SVGElement;
    if (floor) { floor.style.transformBox = 'fill-box'; floor.style.transformOrigin = 'center'; }

    anime({ targets: bus.querySelectorAll('#rotate-left, #rotate-right'), rotate: 460, duration: 2000, loop: true, easing: 'linear' });
    anime({ targets: bus.querySelector('#bus'), translateY: -3, duration: 170, loop: true, direction: 'alternate', easing: 'linear' });
    anime({ targets: bus.querySelectorAll('#tire-left, #tire-right'), translateY: -2.3, duration: 300, loop: true, direction: 'alternate', easing: 'linear' });
    anime({ targets: floor, scaleX: 0.98, duration: 400, loop: true, direction: 'alternate', easing: 'linear' });

    const ids = ['#_2','#_3','#_7','#_8','#_6','#_5','#_4','#_1'];
    const tl = anime.timeline({ loop: true });
    ids.forEach((id, i) => {
      const line = bus.querySelector(id) as SVGLineElement;
      if (!line) return;
      const len = line.getTotalLength();
      line.style.strokeDasharray = String(len);
      line.style.strokeDashoffset = String(len);
      tl.add({ targets: line, strokeDashoffset: [len, 0], duration: 500, easing: 'easeOutQuad' }, i * 250);
      tl.add({ targets: line, strokeDashoffset: [0, -len], duration: 300, easing: 'easeInQuad' }, i * 250 + 500);
    });
  }, [splashVisible]);

  return (
    <div className="login-page">

      {/* Toast container */}
      <div style={{
        position: 'fixed', top: '20px', right: '20px',
        zIndex: 9999, width: '380px', maxWidth: '90vw',
      }}>
        {toasts.map(t => (
          <NeonToast key={t.id} toast={t} onClose={() => removeToast(t.id)} />
        ))}
      </div>

      {/* Splash screen */}
      {splashVisible && (
        <div ref={splashRef} className={`splash-overlay ${splashFading ? 'splash-fading' : ''}`}>
          <section className="splash-section">
            <svg className="splash-logo" width="36rem" height="12rem" viewBox="0 0 640 200">
              <defs>
                <radialGradient cx="50%" cy="0%" fx="50%" fy="0%" r="50%" id="rg-indigo">
                  <stop stopColor="#6a70e0" offset="0%"/>
                  <stop stopColor="#3b3f8f" offset="100%"/>
                </radialGradient>
                <radialGradient cx="50%" cy="0%" fx="50%" fy="0%" r="50%" id="rg-teal">
                  <stop stopColor="#40d8b0" offset="0%"/>
                  <stop stopColor="#1a8a7a" offset="100%"/>
                </radialGradient>
                <radialGradient cx="50%" cy="0%" fx="50%" fy="0%" r="100%" id="rg-green">
                  <stop stopColor="#6ae894" offset="0%"/>
                  <stop stopColor="#3da55c" offset="100%"/>
                </radialGradient>
              </defs>
              <g stroke="none" strokeWidth="1" fill="none" fillRule="evenodd">
                <rect id="splash-dot" fill="#40d8b0" x="24" y="28" width="18" height="18" rx="9" opacity="0"/>
                <g id="splash-lines" transform="translate(24, 36)">
                  <path id="line-b-1" d="M 16,128 L 16,0" stroke="#3b3f8f" strokeWidth="32" strokeLinecap="round"/>
                  <path id="line-b-2" d="M 16,0 C 58,0 58,64 16,64" stroke="#6a70e0" strokeWidth="32"/>
                  <path id="line-b-3" d="M 16,64 C 66,64 66,128 16,128" stroke="#3b3f8f" strokeWidth="32"/>
                  <path id="line-u" d="M 112,0 L 112,80 C 112,106.5 133.5,128 160,128 C 186.5,128 208,106.5 208,80 L 208,0" stroke="#1a8a7a" strokeWidth="32"/>
                  <path id="line-s" d="M 304,28 C 304,8 288,0 272,0 C 256,0 240,10 240,32 C 240,56 260,66 280,72 C 296,78 312,88 312,104 C 312,126 296,128 276,128 C 260,128 244,118 240,100" stroke="#3da55c" strokeWidth="32"/>
                  <path id="line-g" d="M 408,36 C 398,12 384,0 368,0 C 345,0 336,28.6 336,64 C 336,99.3 345,128 368,128 C 384,128 398,116 408,92 L 408,64 L 372,64" stroke="#3b3f8f" strokeWidth="32"/>
                  <path id="line-o" d="M 496,0 C 522.5,0 544,28.6 544,64 C 544,99.3 522.5,128 496,128 C 469.5,128 448,99.3 448,64 C 448,28.6 469.5,0 496,0 Z" stroke="#1a8a7a" strokeWidth="32"/>
                </g>
                <g id="splash-fills" transform="translate(24, 36)">
                  <path d="M 16,128 L 16,0" stroke="url(#rg-indigo)" strokeWidth="32" strokeLinecap="round" opacity="0"/>
                  <path d="M 16,0 C 58,0 58,64 16,64" stroke="url(#rg-indigo)" strokeWidth="32" fill="url(#rg-indigo)" opacity="0"/>
                  <path d="M 16,64 C 66,64 66,128 16,128" stroke="url(#rg-teal)" strokeWidth="32" fill="url(#rg-teal)" opacity="0"/>
                  <path d="M 112,0 L 112,80 C 112,106.5 133.5,128 160,128 C 186.5,128 208,106.5 208,80 L 208,0" stroke="url(#rg-teal)" strokeWidth="32" opacity="0"/>
                  <path d="M 304,28 C 304,8 288,0 272,0 C 256,0 240,10 240,32 C 240,56 260,66 280,72 C 296,78 312,88 312,104 C 312,126 296,128 276,128 C 260,128 244,118 240,100" stroke="url(#rg-green)" strokeWidth="32" opacity="0"/>
                  <path d="M 408,36 C 398,12 384,0 368,0 C 345,0 336,28.6 336,64 C 336,99.3 345,128 368,128 C 384,128 398,116 408,92 L 408,64 L 372,64" stroke="url(#rg-indigo)" strokeWidth="32" opacity="0"/>
                  <path d="M 496,0 C 522.5,0 544,28.6 544,64 C 544,99.3 522.5,128 496,128 C 469.5,128 448,99.3 448,64 C 448,28.6 469.5,0 496,0 Z" stroke="url(#rg-teal)" strokeWidth="32" fill="url(#rg-teal)" opacity="0"/>
                </g>
              </g>
            </svg>
            <div className="splash-subtitle">A &nbsp; X &nbsp; I &nbsp; S</div>
          </section>
        </div>
      )}

      {/* Left panel — Form */}
      <div className="login-left">
        <div className="login-brand">
          <img src={busgoLogo} alt="BUSGO" className="login-brand-logo" />
          <span className="login-brand-name">BUSGO AXIS</span>
        </div>

        <div className="login-form-area">
          <h1 className="login-title">Welcome back</h1>
          <p className="login-subtitle">Sign in to your admin console</p>

          <form onSubmit={handleSubmit} className="login-form">
            <div className="login-field">
              <label className="login-label">Email Address</label>
              <input type="email" placeholder="admin@busgo.lk" value={email}
                onChange={(e) => setEmail(e.target.value)} className="login-input" required />
            </div>
            <div className="login-field">
              <label className="login-label">Password</label>
              <div className="login-password-wrap">
                <input type={showPassword ? 'text' : 'password'} placeholder="Enter your password"
                  value={password} onChange={(e) => setPassword(e.target.value)} className="login-input" required />
                <button type="button" className="login-eye-btn" onClick={() => setShowPassword(!showPassword)} tabIndex={-1}>
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>
            <div className="login-remember">
              <label className="login-remember-label">
                <input type="checkbox" checked={rememberMe} onChange={(e) => setRememberMe(e.target.checked)} className="login-checkbox" />
                <span className="login-checkmark"></span>
                <span>Remember me</span>
              </label>
            </div>
            <button type="submit" className="login-submit" disabled={loading}>
              {loading ? <span className="login-spinner"></span> : 'Sign In'}
            </button>
          </form>

          <div className="login-footer">
            <div className="login-secured"><span className="login-secured-dot"></span>Secured · Enterprise Grade</div>
            <div className="login-copyright">&copy; 2025 BUSGO AXIS. All rights reserved.</div>
          </div>
        </div>
      </div>

      {/* Right panel */}
      <div className="login-right">
        <div className="login-right-content">
          <div className="login-hero-logo-wrap">
            <img src={busgoLogo} alt="" className="login-hero-logo" />
          </div>
          <h2 className="login-hero-title">BUSGO AXIS</h2>
          <p className="login-hero-tagline">Intelligent Bus Fleet Management</p>
          <div ref={busRef} className="bus-animation-wrap" dangerouslySetInnerHTML={{ __html: busSvgRaw }} />
          <div className="login-hero-features">
            <div className="login-hero-feature"><div className="login-hero-feature-dot"></div><span>Real-time GPS Tracking</span></div>
            <div className="login-hero-feature"><div className="login-hero-feature-dot"></div><span>AI-Powered Emergency Alerts</span></div>
            <div className="login-hero-feature"><div className="login-hero-feature-dot"></div><span>Smart Fleet Analytics</span></div>
          </div>
        </div>
        <div className="login-right-decor login-right-decor-1"></div>
        <div className="login-right-decor login-right-decor-2"></div>
      </div>

      <style>{`
        @keyframes slideDown {
          from { transform: translateY(-20px); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
      `}</style>
    </div>
  );
}


