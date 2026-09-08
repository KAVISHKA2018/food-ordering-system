import apiClient from '../services/apiClient';
import { API_CONFIG } from '../config/apiConfig';

import { useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import restaurantService from '../services/restaurantService';
import { imageUrl } from '../config/apiConfig';


const POLL_INTERVAL_MS = 20000; // refresh badge counts every 20s

export default function Sidebar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [restaurant, setRestaurant] = useState(null);
  const [counts, setCounts] = useState({ orders: 0, tables: 0, reservations: 0 });

  useEffect(() => {
    restaurantService
      .getMyRestaurant()
      .then((r) => setRestaurant(r))
      .catch(() => setRestaurant(null));
  }, []);

  useEffect(() => {
    let cancelled = false;

    const loadCounts = async () => {
      try {
        const [ordersRes, sessionsRes, reservationsRes] = await Promise.all([
          apiClient.get(`${API_CONFIG.orders}active_count/`),
          apiClient.get(`${API_CONFIG.tableSessions}active_count/`),
          apiClient.get(`${API_CONFIG.reservations}active_count/`),
        ]);
        if (cancelled) return;

        setCounts({
          orders: ordersRes.data.count,
          tables: sessionsRes.data.count,
          reservations: reservationsRes.data.count,
        });
      } catch {
        // silently ignore — badges just won't update this cycle
      }
    };

    loadCounts();
    const interval = setInterval(loadCounts, POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const linkStyle = ({ isActive }) => ({
    ...styles.link,
    backgroundColor: isActive ? '#E8865A' : 'transparent',
    color: isActive ? '#fff' : '#2B2B2B',
  });

  const logoUrl = restaurant ? imageUrl(restaurant.logo) : null;

  const Badge = ({ count }) => {
    if (!count) return null;
    return <span style={styles.badge}>{count > 99 ? '99+' : count}</span>;
  };

  return (
    <div style={styles.sidebar}>
      <div>
        <div style={styles.brand}>
          {logoUrl ? (
            <img src={logoUrl} alt="logo" style={styles.logoImg} />
          ) : (
            <div style={styles.logoPlaceholder}>🍽️</div>
          )}
          <div>
            <h2 style={styles.restaurantName}>
              {restaurant?.name || 'Loading...'}
            </h2>
            <p style={styles.username}>
               Restaurant Admin
            </p>
          </div>
        </div>

        <nav style={styles.nav}>
          <NavLink to="/dashboard" style={linkStyle}>Dashboard</NavLink>
          <NavLink to="/menu" style={linkStyle}>Menu Management</NavLink>
          <NavLink to="/orders" style={({ isActive }) => linkStyle({ isActive })}>
            <span style={styles.linkRow}>
              Orders
              <Badge count={counts.orders} />
            </span>
          </NavLink>
          <NavLink to="/reservations" style={linkStyle}>
            <span style={styles.linkRow}>
              Reservations
              <Badge count={counts.reservations} />
            </span>
          </NavLink>
          <NavLink to="/tables" style={linkStyle}>
            <span style={styles.linkRow}>
              Tables
              <Badge count={counts.tables} />
            </span>
          </NavLink>
          <NavLink to="/promotions" style={linkStyle}>Promotions</NavLink>
          <NavLink to="/reviews" style={linkStyle}>Reviews</NavLink>
          <NavLink to="/reports" style={linkStyle}>Reports</NavLink>
        </nav>
      </div>

      <button style={styles.logoutBtn} onClick={handleLogout}>
        Logout
      </button>
    </div>
  );
}

const styles = {
  sidebar: {
    width: '220px',
    height: '100%',
    backgroundColor: '#fff',
    borderRight: '1px solid #eee',
    padding: '24px 16px',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'space-between',
    boxSizing: 'border-box',
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginBottom: '28px',
  },
  logoImg: {
    width: '40px',
    height: '40px',
    borderRadius: '10px',
    objectFit: 'cover',
    flexShrink: 0,
  },
  logoPlaceholder: {
    width: '40px',
    height: '40px',
    borderRadius: '10px',
    backgroundColor: '#FBE0D1',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '18px',
    flexShrink: 0,
  },
  restaurantName: {
    fontSize: '15px',
    margin: 0,
    lineHeight: 1.3,
    wordBreak: 'break-word',
  },
  username: { fontSize: '12px', color: '#8E8E8E', marginTop: '4px' },
  nav: { display: 'flex', flexDirection: 'column', gap: '4px' },
  link: {
    display: 'block',
    padding: '10px 14px',
    borderRadius: '8px',
    textDecoration: 'none',
    fontSize: '14px',
    fontWeight: 500,
  },
  linkRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  badge: {
    backgroundColor: '#E53935',
    color: '#fff',
    borderRadius: '10px',
    fontSize: '11px',
    fontWeight: 700,
    padding: '2px 7px',
    minWidth: '18px',
    textAlign: 'center',
    lineHeight: 1.4,
  },
  logoutBtn: {
    padding: '10px',
    backgroundColor: '#fff',
    border: '1px solid #E53935',
    color: '#E53935',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '14px',
  },
};