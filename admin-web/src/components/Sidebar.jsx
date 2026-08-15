import { useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import restaurantService from '../services/restaurantService';
import { imageUrl } from '../config/apiConfig';

export default function Sidebar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [restaurant, setRestaurant] = useState(null);

  useEffect(() => {
    restaurantService
      .getMyRestaurant()
      .then((r) => setRestaurant(r))
      .catch(() => setRestaurant(null));
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