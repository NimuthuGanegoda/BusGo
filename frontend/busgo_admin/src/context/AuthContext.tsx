import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import { authApi, TokenStore, type User } from '../services/api';

interface AuthContextValue {
  user: User | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Restore session from localStorage on mount
  useEffect(() => {
    const token = TokenStore.getAccess();
    if (!token) { setIsLoading(false); return; }
    // Decode JWT to get user info (no verify needed — server verifies on each request)
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      if (payload.exp * 1000 > Date.now()) {
        // Token still valid — fetch full profile
        fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:5000/api'}/users/me`, {
          headers: { Authorization: `Bearer ${token}` },
        })
          .then(r => r.json())
          .then(d => { if (d.data) setUser(d.data); })
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
    if (result.user.role !== 'admin') {
      throw new Error('This account is not authorized to access this panel.');
    }
    TokenStore.set(result.access_token, result.refresh_token);
    setUser(result.user);
  }, []);

  const logout = useCallback(async () => {
    const refresh = TokenStore.getRefresh();
    if (refresh) await authApi.logout(refresh).catch(() => {});
    TokenStore.clear();
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be inside AuthProvider');
  return ctx;
}
