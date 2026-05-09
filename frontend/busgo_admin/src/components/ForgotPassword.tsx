import { useState } from 'react';
import { Shield, ArrowLeft } from 'lucide-react';

interface Props {
  onBack: () => void;
}

const QUESTIONS = [
  'Which degree are you completing?',
  'What is the name of your pet?',
  'Which school did you go to?',
];

export default function ForgotPassword({ onBack }: Props) {
  const [step, setStep]       = useState<'email' | 'verify' | 'done'>('email');
  const [email, setEmail]     = useState('');
  const [pin, setPin]         = useState('');
  const [answer1, setAnswer1] = useState('');
  const [answer2, setAnswer2] = useState('');
  const [answer3, setAnswer3] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');

  const API = import.meta.env.VITE_API_URL || 'https://busgo-production.up.railway.app/api';

  const handleEmailNext = async () => {
    setError('');
    if (!email.trim()) { setError('Please enter your email.'); return; }
    setStep('verify');
  };

  const handleSubmit = async () => {
    setError('');
    if (!pin || !/^\d{6}$/.test(pin)) { setError('Enter your 6-digit recovery PIN.'); return; }
    if (!answer1.trim() || !answer2.trim() || !answer3.trim()) {
      setError('Please answer all three questions.'); return;
    }
    setLoading(true);
    try {
      const res = await fetch(`${API}/auth/admin/recovery-request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email.trim().toLowerCase(),
          recovery_pin: pin,
          answer_1: answer1.trim().toLowerCase(),
          answer_2: answer2.trim().toLowerCase(),
          answer_3: answer3.trim().toLowerCase(),
        }),
      });
      const data = await res.json();
      if (!res.ok) { setError(data.message || 'Verification failed.'); setLoading(false); return; }
      setStep('done');
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const inputStyle: React.CSSProperties = {
    width: '100%', padding: '12px 14px', borderRadius: '10px',
    border: '1.5px solid #e5e7eb', fontSize: '14px',
    outline: 'none', boxSizing: 'border-box', marginTop: '6px',
  };

  const btnStyle: React.CSSProperties = {
    width: '100%', padding: '13px', borderRadius: '10px',
    background: 'linear-gradient(135deg, #1a6cf0, #0d47a1)',
    color: 'white', fontWeight: 700, fontSize: '15px',
    border: 'none', cursor: 'pointer', marginTop: '20px',
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center',
      justifyContent: 'center', background: '#f8fafc', padding: '20px',
    }}>
      <div style={{
        background: 'white', borderRadius: '16px', padding: '40px',
        width: '100%', maxWidth: '480px',
        boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
      }}>
        <button onClick={onBack} style={{
          background: 'none', border: 'none', cursor: 'pointer',
          color: '#6b7280', display: 'flex', alignItems: 'center',
          gap: '6px', fontSize: '13px', marginBottom: '20px', padding: 0,
        }}>
          <ArrowLeft size={16} /> Back to login
        </button>

        <div style={{ textAlign: 'center', marginBottom: '28px' }}>
          <div style={{
            width: '56px', height: '56px', borderRadius: '14px',
            background: 'linear-gradient(135deg, #f59e0b, #d97706)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 14px',
          }}>
            <Shield size={28} color="white" />
          </div>
          <h1 style={{ fontSize: '22px', fontWeight: 800, color: '#111827', margin: 0 }}>
            Account Recovery
          </h1>
          <p style={{ fontSize: '13px', color: '#6b7280', marginTop: '6px' }}>
            Verify your identity to request a password reset.
          </p>
        </div>

        {error && (
          <div style={{
            background: '#fef2f2', border: '1px solid #fca5a5',
            borderRadius: '8px', padding: '10px 14px',
            color: '#dc2626', fontSize: '13px', marginBottom: '16px',
          }}>
            {error}
          </div>
        )}

        {/* Step 1 — Email */}
        {step === 'email' && (
          <div>
            <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
              Admin Email
            </label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="your@email.com"
              style={inputStyle}
            />
            <button onClick={handleEmailNext} style={btnStyle}>
              Continue →
            </button>
          </div>
        )}

        {/* Step 2 — PIN + Questions */}
        {step === 'verify' && (
          <div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                Recovery PIN (6 digits)
              </label>
              <input
                type="password"
                value={pin}
                onChange={e => setPin(e.target.value.replace(/\D/g, '').slice(0, 6))}
                placeholder="Your recovery PIN"
                style={inputStyle}
                maxLength={6}
              />
            </div>

            {QUESTIONS.map((q, i) => (
              <div key={i} style={{ marginBottom: '16px' }}>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                  Q{i + 1}: {q}
                </label>
                <input
                  type="text"
                  value={[answer1, answer2, answer3][i]}
                  onChange={e => [setAnswer1, setAnswer2, setAnswer3][i](e.target.value)}
                  placeholder="Your answer"
                  style={inputStyle}
                />
              </div>
            ))}

            <div style={{ display: 'flex', gap: '10px' }}>
              <button onClick={() => setStep('email')} style={{
                ...btnStyle, background: '#f3f4f6', color: '#374151', flex: 1,
              }}>
                ← Back
              </button>
              <button onClick={handleSubmit} disabled={loading} style={{ ...btnStyle, flex: 2 }}>
                {loading ? 'Verifying...' : 'Submit Request'}
              </button>
            </div>
          </div>
        )}

        {/* Step 3 — Done */}
        {step === 'done' && (
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>✅</div>
            <h2 style={{ fontSize: '18px', fontWeight: 700, color: '#111827' }}>
              Request Submitted
            </h2>
            <p style={{ fontSize: '13px', color: '#6b7280', marginTop: '8px', lineHeight: 1.6 }}>
              Your identity has been verified. A developer will review your request
              and provide a temporary password within 24 hours via a secure channel.
            </p>
            <button onClick={() => { window.location.href = '/admin/login'; }}>
              Back to Login
            </button>
          </div>
        )}
      </div>
    </div>
  );
}


