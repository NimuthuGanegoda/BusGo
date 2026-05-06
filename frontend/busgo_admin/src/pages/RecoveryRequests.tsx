import { useState, useEffect, useCallback } from 'react';
import { KeyRound, RefreshCw, CheckCircle, Clock, Copy } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

const API   = 'https://busgo-production.up.railway.app/api';
const ADMIN = 'https://busgo-production.up.railway.app/api/admin';

type RecoveryEntry = {
  id: string;
  user_id: string | null;
  email: string | null;
  details: {
    full_name?: string;
    verified_at?: string;
    status?: string;
  };
  created_at: string;
};

function generateTempPassword(): string {
  const upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower   = 'abcdefghjkmnpqrstuvwxyz';
  const digits  = '23456789';
  const special = '!@#$';
  const all     = upper + lower + digits + special;
  let pass = '';
  pass += upper[Math.floor(Math.random() * upper.length)];
  pass += lower[Math.floor(Math.random() * lower.length)];
  pass += digits[Math.floor(Math.random() * digits.length)];
  pass += special[Math.floor(Math.random() * special.length)];
  for (let i = 4; i < 12; i++) pass += all[Math.floor(Math.random() * all.length)];
  return pass.split('').sort(() => Math.random() - 0.5).join('');
}

export default function RecoveryRequests() {
  const { user, accessToken } = useAuth();
  const navigate = useNavigate();
  const [requests,   setRequests]   = useState<RecoveryEntry[]>([]);
  const [loading,    setLoading]    = useState(true);
  const [processing, setProcessing] = useState<string | null>(null);
  const [toast,      setToast]      = useState('');
  const [toastType,  setToastType]  = useState<'success' | 'error'>('success');
  const [doneMap,    setDoneMap]    = useState<Record<string, string>>({});

  useEffect(() => {
    if (user && user.role !== 'developer') navigate('/admin/dashboard');
  }, [user, navigate]);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast(msg); setToastType(type);
    setTimeout(() => setToast(''), 5000);
  };

  const fetchRequests = useCallback(async () => {
    if (!accessToken) return;
    setLoading(true);
    try {
      const res  = await fetch(
        `${ADMIN}/security-logs?event_type=ADMIN_RECOVERY_REQUEST&page_size=50&page=1`,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      const json = await res.json();
      const data = json.data?.data ?? json.data ?? [];
      const pending = (Array.isArray(data) ? data : []).filter(
        (r: any) => r.details?.status !== 'resolved'
      );
      setRequests(pending);
    } catch (e) {
      console.error('[RecoveryRequests]', e);
    } finally {
      setLoading(false);
    }
  }, [accessToken]);

  useEffect(() => { fetchRequests(); }, [fetchRequests]);

  const handleApprove = async (entry: RecoveryEntry) => {
    if (!entry.user_id || !entry.email) {
      showToast('Cannot resolve — no user linked to this request', 'error');
      return;
    }
    setProcessing(entry.id);
    const tempPassword = generateTempPassword();
    try {
      const res  = await fetch(`${API}/auth/admin/resolve-recovery`, {
        method:  'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization:  `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          user_id:       entry.user_id,
          email:         entry.email,
          temp_password: tempPassword,
        }),
      });
      const json = await res.json();
      if (!res.ok) {
        showToast(`Failed: ${json.message || 'Unknown error'}`, 'error');
        setProcessing(null);
        return;
      }
      setDoneMap(prev => ({ ...prev, [entry.id]: tempPassword }));
      showToast(`✅ Temp password generated for ${entry.email}`);
      fetchRequests();
    } catch (e) {
      showToast('Network error — could not reach backend', 'error');
    } finally {
      setProcessing(null);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    showToast('Copied to clipboard');
  };

  return (
    <div style={{ padding: '24px', maxWidth: '900px' }}>
      {toast && (
        <div style={{
          position: 'fixed', top: '20px', right: '20px', zIndex: 9999,
          background: toastType === 'error' ? '#dc2626' : '#16a34a',
          color: 'white', padding: '12px 20px', borderRadius: '10px',
          fontSize: '13px', fontWeight: 600,
          display: 'flex', alignItems: 'center', gap: '8px',
          boxShadow: '0 4px 12px rgba(0,0,0,0.2)',
        }}>
          <CheckCircle size={16} /> {toast}
        </div>
      )}

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '44px', height: '44px', borderRadius: '12px',
            background: 'linear-gradient(135deg, #f59e0b, #d97706)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <KeyRound size={22} color="white" />
          </div>
          <div>
            <h1 style={{ fontSize: '20px', fontWeight: 800, color: '#111827', margin: 0 }}>
              Recovery Requests
            </h1>
            <p style={{ fontSize: '13px', color: '#6b7280', margin: 0 }}>
              Admin password reset requests — visible to developers only
            </p>
          </div>
        </div>
        <button onClick={fetchRequests} style={{
          display: 'flex', alignItems: 'center', gap: '6px',
          padding: '8px 16px', borderRadius: '8px',
          background: '#f3f4f6', border: '1px solid #e5e7eb',
          cursor: 'pointer', fontSize: '13px', fontWeight: 600, color: '#374151',
        }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      <div style={{
        background: '#fffbeb', border: '1px solid #f59e0b',
        borderRadius: '10px', padding: '12px 16px',
        fontSize: '13px', color: '#92400e', marginBottom: '24px',
      }}>
        ⚠ <strong>Developer only.</strong> Clicking Approve will automatically generate a
        temporary password and share it securely with the admin via a secure channel (e.g. WhatsApp or Google Meet).
        The admin will be forced to set a new password, PIN and security questions on next login.
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px', color: '#6b7280' }}>Loading requests...</div>
      ) : requests.length === 0 ? (
        <div style={{
          background: '#f0fdf4', border: '1px solid #bbf7d0',
          borderRadius: '10px', padding: '40px', textAlign: 'center',
          color: '#15803d', fontSize: '14px',
        }}>
          ✅ No pending recovery requests
        </div>
      ) : (
        <>
          <h2 style={{ fontSize: '15px', fontWeight: 700, color: '#111827', marginBottom: '12px' }}>
            Pending ({requests.length})
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {requests.map(entry => (
              <div key={entry.id} style={{
                background: 'white', border: '1px solid #fde68a',
                borderRadius: '12px', padding: '20px',
                boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '15px', color: '#111827' }}>
                      {entry.details?.full_name || 'Unknown Admin'}
                    </div>
                    <div style={{ fontSize: '13px', color: '#6b7280', marginTop: '4px' }}>
                      {entry.email || '—'}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '8px' }}>
                      <Clock size={12} color="#9ca3af" />
                      <span style={{ fontSize: '12px', color: '#9ca3af' }}>
                        {new Date(entry.created_at).toLocaleString('en-LK', { timeZone: 'Asia/Colombo' })}
                      </span>
                    </div>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '10px' }}>
                    {doneMap[entry.id] ? (
                      <>
                        <span style={{
                          background: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0',
                          padding: '3px 10px', borderRadius: '6px', fontSize: '11px', fontWeight: 700,
                        }}>✅ PASSWORD GENERATED</span>
                        <div style={{
                          background: '#f9fafb', border: '1px solid #e5e7eb',
                          borderRadius: '8px', padding: '10px 14px',
                          display: 'flex', alignItems: 'center', gap: '10px',
                        }}>
                          <div>
                            <div style={{ fontSize: '11px', color: '#6b7280', marginBottom: '2px' }}>
                              Share via secure channel:
                            </div>
                            <code style={{ fontSize: '14px', fontWeight: 700, color: '#111827' }}>
                              {doneMap[entry.id]}
                            </code>
                          </div>
                          <button onClick={() => copyToClipboard(doneMap[entry.id])}
                            style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#6b7280' }}>
                            <Copy size={16} />
                          </button>
                        </div>
                      </>
                    ) : (
                      <>
                        <span style={{
                          background: '#fffbeb', color: '#d97706', border: '1px solid #f59e0b',
                          padding: '3px 10px', borderRadius: '6px', fontSize: '11px', fontWeight: 700,
                        }}>PENDING</span>
                        <button onClick={() => handleApprove(entry)} disabled={processing === entry.id} style={{
                          background: '#16a34a', color: 'white', border: 'none', borderRadius: '8px',
                          padding: '10px 18px', fontSize: '13px', fontWeight: 600,
                          cursor: processing === entry.id ? 'not-allowed' : 'pointer',
                          opacity: processing === entry.id ? 0.7 : 1,
                        }}>
                          {processing === entry.id ? 'Generating...' : '✓ Approve & Generate Password'}
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}