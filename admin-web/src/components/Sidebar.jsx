import { useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import restaurantService from '../services/restaurantService';

export default function Sidebar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [restaurantName, setRestaurantName] = useState('');

  useEffect(() => {
    restaurantService
      .getMyRestaurant()
      .then((r) => setRestaurantName(r?.name || ''))
      .catch(() => setRestaurantName(''));
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

  return (
    <div style={styles.sidebar}>
      <div>
        <div style={styles.brand}>
          <span style={styles.brandIcon}>🍽️</span>
          <div>
            <h2 style={styles.restaurantName}>
              {restaurantName || 'Loading...'}
            </h2>
            <p style={styles.username}>
              {user?.username} · Restaurant Admin
            </p>
          </div>
        </div>

        <nav style={styles.nav}>
          <NavLink to="/dashboard" style={linkStyle}>Dashboard</NavLink>
          <NavLink to="/menu" style={linkStyle}>Menu Management</NavLink>
          <NavLink to="/orders" style={linkStyle}>Orders</NavLink>
          <NavLink to="/reservations" style={linkStyle}>Reservations</NavLink>
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
    minHeight: '100vh',
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
    alignItems: 'flex-start',
    gap: '8px',
    marginBottom: '28px',
  },
  brandIcon: { fontSize: '22px' },
  restaurantName: {
    fontSize: '16px',
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