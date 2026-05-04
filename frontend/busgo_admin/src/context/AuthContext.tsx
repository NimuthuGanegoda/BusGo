import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import { authApi, TokenStore, type User } from '../services/api';

interface AuthContextValue {
  user:          User | null;
  isLoading:     boolean;
  isFirstLogin:  boolean;
  accessToken:   string | null;
  login:         (email: string, password: string) => Promise<void>;
  logout:        () => Promise<void>;
  completeSetup: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user,         setUser]         = useState<User | null>(null);
  const [isLoading,    setIsLoading]    = useState(true);
  const [isFirstLogin, setIsFirstLogin] = useState(false);
  const [accessToken,  setAccessToken]  = useState<string | null>(null);

  // Restore session from localStorage on mount
  useEffect(() => {
    const token = TokenStore.getAccess();
    if (!token) { setIsLoading(false); return; }
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      if (payload.exp * 1000 > Date.now()) {
        fetch(`${import.meta.env.VITE_API_URL || 'https://busgo-production.up.railway.app/api'}/users/me`, {
          headers: { Authorization: `Bearer ${token}` },
        })
          .then(r => r.json())
          .then(d => {
            if (d.data) {
              setUser(d.data);
              setAccessToken(token);
              setIsFirstLogin(d.data.is_first_login === true);
            }
          })
          .catch(() => TokenStore.clear())
          .finally(() => setIsLoading(false));
      } else {
        TokenStore.clear();
        setIsLoading(false);
      }
    } catch {
      setIsLoading(false);
    }
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const result = await authApi.login(email, password);
    if (!['admin', 'developer'].includes(result.user.role)) {
      throw new Error('This account is not authorized to access this panel.');
    }
    TokenStore.set(result.access_token, result.refresh_token);
    setUser(result.user);
    setAccessToken(result.access_token);
    setIsFirstLogin((result.user as any).is_first_login === true);
  }, []);

  const logout = useCallback(async () => {
    const refresh = TokenStore.getRefresh();
    if (refresh) await authApi.logout(refresh).catch(() => {});
    TokenStore.clear();
    setUser(null);
    setAccessToken(null);
    setIsFirstLogin(false);
  }, []);

  // Called after first-login setup is complete
  const completeSetup = useCallback(() => {
    setIsFirstLogin(false);
  }, []);

  return (
    <AuthContext.Provider value={{
      user, isLoading, isFirstLogin, accessToken,
      login, logout, completeSetup,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be inside AuthProvider');
  return ctx;
}


