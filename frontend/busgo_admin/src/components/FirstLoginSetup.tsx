import { useState } from 'react';
import { Eye, EyeOff, Shield, Lock, HelpCircle } from 'lucide-react';

interface Props {
  email: string;
  accessToken: string;
  onComplete: () => void;
}

export default function FirstLoginSetup({ email, accessToken, onComplete }: Props) {
  const [step, setStep]               = useState<'password' | 'pin' | 'questions'>('password');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPass, setConfirmPass] = useState('');
  const [pin, setPin]                 = useState('');
  const [confirmPin, setConfirmPin]   = useState('');
  const [answer1, setAnswer1]         = useState('');
  const [answer2, setAnswer2]         = useState('');
  const [answer3, setAnswer3]         = useState('');
  const [showPass, setShowPass]       = useState(false);
  const [loading, setLoading]         = useState(false);
  const [error, setError]             = useState('');

  const API = import.meta.env.VITE_API_URL || 'https://busgo-production.up.railway.app/api';

  const handlePasswordNext = () => {
    setError('');
    if (newPassword.length < 8) { setError('Password must be at least 8 characters.'); return; }
    if (!/[A-Z]/.test(newPassword)) { setError('Must contain an uppercase letter.'); return; }
    if (!/[0-9]/.test(newPassword)) { setError('Must contain a number.'); return; }
    if (!/[!@#$%^&*]/.test(newPassword)) { setError('Must contain a special character (!@#$%^&*).'); return; }
    if (newPassword !== confirmPass) { setError('Passwords do not match.'); return; }
    setStep('pin');
  };

  const handlePinNext = () => {
    setError('');
    if (!/^\d{6}$/.test(pin)) { setError('PIN must be exactly 6 digits.'); return; }
    if (pin !== confirmPin) { setError('PINs do not match.'); return; }
    setStep('questions');
  };

  const handleSubmit = async () => {
    setError('');
    if (!answer1.trim() || !answer2.trim() || !answer3.trim()) {
      setError('Please answer all three questions.'); return;
    }
    setLoading(true);
    try {
      const res = await fetch(`${API}/auth/admin/setup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          new_password: newPassword,
          recovery_pin: pin,
          answer_1: answer1.trim().toLowerCase(),
          answer_2: answer2.trim().toLowerCase(),
          answer_3: answer3.trim().toLowerCase(),
        }),
      });
      const data = await res.json();
      if (!res.ok) { setError(data.message || 'Setup failed.'); setLoading(false); return; }
      onComplete();
    } catch {
      setError('Network error. Please try again.');
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
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: '28px' }}>
          <div style={{
            width: '56px', height: '56px', borderRadius: '14px',
            background: 'linear-gradient(135deg, #1a6cf0, #0d47a1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 14px',
          }}>
            <Shield size={28} color="white" />
          </div>
          <h1 style={{ fontSize: '22px', fontWeight: 800, color: '#111827', margin: 0 }}>
            Account Setup Required
          </h1>
          <p style={{ fontSize: '13px', color: '#6b7280', marginTop: '6px' }}>
            {step === 'password' && 'Set your new password to secure your account.'}
            {step === 'pin' && 'Create a 6-digit recovery PIN.'}
            {step === 'questions' && 'Answer security questions for account recovery.'}
          </p>
        </div>

        {/* Step indicators */}
        <div style={{ display: 'flex', gap: '8px', marginBottom: '28px' }}>
          {['password', 'pin', 'questions'].map((s, i) => (
            <div key={s} style={{
              flex: 1, height: '4px', borderRadius: '2px',
              background: ['password', 'pin', 'questions'].indexOf(step) >= i
                ? '#1a6cf0' : '#e5e7eb',
            }} />
          ))}
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

        {/* Step 1 — New Password */}
        {step === 'password' && (
          <div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                New Password
              </label>
              <div style={{ position: 'relative' }}>
                <input
                  type={showPass ? 'text' : 'password'}
                  value={newPassword}
                  onChange={e => setNewPassword(e.target.value)}
                  placeholder="Min 8 chars, uppercase, number, special"
                  style={inputStyle}
                />
                <button onClick={() => setShowPass(v => !v)} style={{
                  position: 'absolute', right: '12px', top: '50%',
                  transform: 'translateY(-50%)', background: 'none',
                  border: 'none', cursor: 'pointer', color: '#9ca3af',
                }}>
                  {showPass ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>
            <div>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                Confirm Password
              </label>
              <input
                type="password"
                value={confirmPass}
                onChange={e => setConfirmPass(e.target.value)}
                placeholder="Re-enter your password"
                style={inputStyle}
              />
            </div>
            <button onClick={handlePasswordNext} style={btnStyle}>
              Next →
            </button>
          </div>
        )}

        {/* Step 2 — Recovery PIN */}
        {step === 'pin' && (
          <div>
            <div style={{
              background: '#eff6ff', borderRadius: '10px',
              padding: '12px 14px', marginBottom: '20px', fontSize: '13px', color: '#1d4ed8',
            }}>
              <Lock size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} />
              This PIN is used only for account recovery — not for login.
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                Recovery PIN (6 digits)
              </label>
              <input
                type="password"
                value={pin}
                onChange={e => setPin(e.target.value.replace(/\D/g, '').slice(0, 6))}
                placeholder="6-digit PIN"
                style={inputStyle}
                maxLength={6}
              />
            </div>
            <div>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                Confirm PIN
              </label>
              <input
                type="password"
                value={confirmPin}
                onChange={e => setConfirmPin(e.target.value.replace(/\D/g, '').slice(0, 6))}
                placeholder="Re-enter PIN"
                style={inputStyle}
                maxLength={6}
              />
            </div>
            <div style={{ display: 'flex', gap: '10px' }}>
              <button onClick={() => setStep('password')} style={{
                ...btnStyle, background: '#f3f4f6', color: '#374151', flex: 1,
              }}>
                ← Back
              </button>
              <button onClick={handlePinNext} style={{ ...btnStyle, flex: 2 }}>
                Next →
              </button>
            </div>
          </div>
        )}

        {/* Step 3 — Security Questions */}
        {step === 'questions' && (
          <div>
            <div style={{
              background: '#f0fdf4', borderRadius: '10px',
              padding: '12px 14px', marginBottom: '20px', fontSize: '13px', color: '#15803d',
            }}>
              <HelpCircle size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} />
              Answers are case-insensitive. Remember them exactly.
            </div>
            {[
              { q: 'Which degree are you completing?', val: answer1, set: setAnswer1 },
              { q: 'What is the name of your pet?',    val: answer2, set: setAnswer2 },
              { q: 'Which school did you go to?',      val: answer3, set: setAnswer3 },
            ].map((item, i) => (
              <div key={i} style={{ marginBottom: '16px' }}>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#374151' }}>
                  Q{i + 1}: {item.q}
                </label>
                <input
                  type="text"
                  value={item.val}
                  onChange={e => item.set(e.target.value)}
                  placeholder="Your answer"
                  style={inputStyle}
                />
              </div>
            ))}
            <div style={{ display: 'flex', gap: '10px' }}>
              <button onClick={() => setStep('pin')} style={{
                ...btnStyle, background: '#f3f4f6', color: '#374151', flex: 1,
              }}>
                ← Back
              </button>
              <button onClick={handleSubmit} disabled={loading} style={{ ...btnStyle, flex: 2 }}>
                {loading ? 'Saving...' : '✓ Complete Setup'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}


