import { createContext, useContext, useState, useEffect } from 'react';
import authService from '../services/authService';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const tryAutoLogin = async () => {
      if (authService.isLoggedIn()) {
        try {
          const currentUser = await authService.getCurrentUser();
          setUser(currentUser);
        } catch {
          authService.logout();
        }
      }
      setLoading(false);
    };
    tryAutoLogin();
  }, []);

  const login = async (username, password) => {
    await authService.login(username, password);
    const currentUser = await authService.getCurrentUser();
    setUser(currentUser);
    return currentUser;
  };

  const logout = () => {
    authService.logout();
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, isLoggedIn: !!user }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}