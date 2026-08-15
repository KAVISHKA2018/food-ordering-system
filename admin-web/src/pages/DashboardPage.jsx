import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { useAuth } from '../context/AuthContext';
import restaurantService from '../services/restaurantService';
import orderService from '../services/orderService';
import reservationService from '../services/reservationService';
import { imageUrl } from '../config/apiConfig';

export default function DashboardPage() {
  const { user } = useAuth();
  const [restaurant, setRestaurant] = useState(null);
  const [orders, setOrders] = useState([]);
  const [reservations, setReservations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [logoFile, setLogoFile] = useState(null);
  const [coverFile, setCoverFile] = useState(null);
  const [logoPreview, setLogoPreview] = useState(null);
  const [coverPreview, setCoverPreview] = useState(null);
  const [savingImages, setSavingImages] = useState(false);

  const [qrUrl, setQrUrl] = useState(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const [restaurantData, orderData, reservationData] = await Promise.all([
        restaurantService.getMyRestaurant(),
        orderService.getOrders(),
        reservationService.getReservations(),
      ]);
      setRestaurant(restaurantData);
      setOrders(orderData);
      setReservations(reservationData);

      if (restaurantData) {
        const url = await restaurantService.getQRCode(restaurantData.id);
        setQrUrl(url);
      }
    } catch (err) {
      setError('Failed to load dashboard data.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setLogoFile(file);
      setLogoPreview(URL.createObjectURL(file));
    }
  };

  const handleCoverChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setCoverFile(file);
      setCoverPreview(URL.createObjectURL(file));
    }
  };

  const saveImages = async () => {
    if (!logoFile && !coverFile) return;
    setSavingImages(true);
    try {
      const formData = new FormData();
      if (logoFile) formData.append('logo', logoFile);
      if (coverFile) formData.append('cover_image', coverFile);
      await restaurantService.updateRestaurantImages(restaurant.id, formData);
      setLogoFile(null);
      setCoverFile(null);
      setLogoPreview(null);
      setCoverPreview(null);
      loadData();
    } catch (err) {
      setError('Failed to update images.');
    } finally {
      setSavingImages(false);
    }
  };

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;
  if (!restaurant) {
    return (
      <Layout>
        <div style={styles.page}>
          <p>No restaurant found for your account. Contact the system admin to get one set up.</p>
        </div>
      </Layout>
    );
  }

  // Stats
  const totalOrders = orders.length;
  const pendingOrders = orders.filter((o) => o.status === 'PENDING').length;
  const completedOrders = orders.filter((o) => o.status === 'COMPLETED').length;
  const totalRevenue = orders
    .filter((o) => o.status === 'COMPLETED')
    .reduce((sum, o) => sum + parseFloat(o.total_amount), 0);

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const upcomingReservations = reservations.filter((r) => {
    const resDate = new Date(r.reservation_date);
    return resDate >= today && !['CANCELLED', 'COMPLETED', 'NO_SHOW'].includes(r.status);
  }).length;
  const pendingReservations = reservations.filter((r) => r.status === 'PENDING').length;

  const recentOrders = [...orders]
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .slice(0, 5);

  const totalMenuItems = restaurant.categories?.reduce(
    (sum, c) => sum + (c.menu_items?.length || 0), 0
  ) || 0;

  return (
    <Layout>
      <div style={styles.page}>
        <h1>Welcome, {user?.username}</h1>
        {error && <div style={styles.error}>{error}</div>}

        {/* Cover + Logo section */}
        <div style={styles.coverCard}>
          <div
            style={{
              ...styles.coverBanner,
              backgroundImage: `url(${coverPreview || imageUrl(restaurant.cover_image) || ''})`,
            }}
          >
            {!coverPreview && !restaurant.cover_image && (
              <span style={styles.coverPlaceholderText}>No cover image set</span>
            )}
            <label style={styles.coverUploadBtn}>
              Change Cover
              <input type="file" accept="image/*" onChange={handleCoverChange} hidden />
            </label>
          </div>

          <div style={styles.logoRow}>
            <div style={styles.logoWrapper}>
              {(logoPreview || restaurant.logo) ? (
                <img
                  src={logoPreview || imageUrl(restaurant.logo)}
                  alt="logo"
                  style={styles.logoImg}
                />
              ) : (
                <div style={styles.logoPlaceholder}>🍽️</div>
              )}
              <label style={styles.logoUploadBtn}>
                ✎
                <input type="file" accept="image/*" onChange={handleLogoChange} hidden />
              </label>
            </div>
            <div>
              <h2 style={{ margin: 0 }}>{restaurant.name}</h2>
              <p style={{ margin: '4px 0 0', color: '#8E8E8E', fontSize: '13px' }}>
                {restaurant.address}
              </p>
            </div>
          </div>

          {(logoFile || coverFile) && (
            <div style={{ padding: '0 20px 20px', display: 'flex', gap: '8px' }}>
              <button style={styles.primaryBtn} onClick={saveImages} disabled={savingImages}>
                {savingImages ? 'Saving...' : 'Save Images'}
              </button>
              <button
                style={styles.secondaryBtn}
                onClick={() => {
                  setLogoFile(null);
                  setCoverFile(null);
                  setLogoPreview(null);
                  setCoverPreview(null);
                }}
              >
                Cancel
              </button>
            </div>
          )}
        </div>

        <div style={styles.qrCard}>
          <div>
            <h3 style={{ margin: '0 0 4px' }}>Table QR Code</h3>
            <p style={{ margin: 0, color: '#8E8E8E', fontSize: '13px' }}>
              Print this and place it on your tables. Customers scan it to start a dine-in order.
            </p>
          </div>
          {qrUrl ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <img src={qrUrl} alt="Restaurant QR Code" style={styles.qrImage} />
              <a href={qrUrl} download={`${restaurant.name}-qr-code.png`} style={styles.primaryBtn}>
                Download
              </a>
            </div>
          ) : (
            <p style={{ color: '#8E8E8E' }}>Loading QR code...</p>
          )}
        </div>
        
        {/* Stats grid */}
        <div style={styles.statsGrid}>
          <StatCard label="Total Orders" value={totalOrders} color="#2196F3" />
          <StatCard label="Pending Orders" value={pendingOrders} color="#FF9800" />
          <StatCard label="Completed Orders" value={completedOrders} color="#4CAF50" />
          <StatCard label="Revenue" value={`Rs. ${totalRevenue.toFixed(0)}`} color="#E8865A" />
          <StatCard label="Menu Items" value={totalMenuItems} color="#9C27B0" />
          <StatCard label="Upcoming Reservations" value={upcomingReservations} color="#009688" />
          <StatCard label="Pending Reservations" value={pendingReservations} color="#795548" />
        </div>

        {/* Recent orders */}
        <div style={styles.section}>
          <h2>Recent Orders</h2>
          {recentOrders.length === 0 ? (
            <p style={{ color: '#8E8E8E' }}>No orders yet.</p>
          ) : (
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>Order</th>
                  <th style={styles.th}>Customer</th>
                  <th style={styles.th}>Status</th>
                  <th style={styles.th}>Total</th>
                  <th style={styles.th}>Date</th>
                </tr>
              </thead>
              <tbody>
                {recentOrders.map((o) => (
                  <tr key={o.id}>
                    <td style={styles.td}>#{o.id}</td>
                    <td style={styles.td}>{o.customer_username}</td>
                    <td style={styles.td}>{o.status}</td>
                    <td style={styles.td}>Rs. {parseFloat(o.total_amount).toFixed(0)}</td>
                    <td style={styles.td}>{new Date(o.created_at).toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </Layout>
  );
}

function StatCard({ label, value, color }) {
  return (
    <div style={styles.statCard}>
      <p style={{ ...styles.statLabel, color }}>{label}</p>
      <p style={styles.statValue}>{value}</p>
    </div>
  );
}

const styles = {
  page: { padding: '32px', maxWidth: '1100px' },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  coverCard: {
    backgroundColor: '#fff', borderRadius: '16px', overflow: 'hidden', marginBottom: '24px',
  },
  coverBanner: {
    height: '180px', backgroundSize: 'cover', backgroundPosition: 'center',
    backgroundColor: '#FBE0D1', position: 'relative',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  },
  coverPlaceholderText: { color: '#C98B5F', fontSize: '14px' },
  coverUploadBtn: {
    position: 'absolute', bottom: '12px', right: '12px',
    backgroundColor: 'rgba(0,0,0,0.6)', color: '#fff', padding: '8px 14px',
    borderRadius: '8px', fontSize: '12px', cursor: 'pointer',
  },
  logoRow: { display: 'flex', alignItems: 'center', gap: '16px', padding: '20px' },
  logoWrapper: { position: 'relative', width: '72px', height: '72px' },
  logoImg: { width: '72px', height: '72px', borderRadius: '14px', objectFit: 'cover' },
  logoPlaceholder: {
    width: '72px', height: '72px', borderRadius: '14px', backgroundColor: '#FBE0D1',
    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '28px',
  },
  logoUploadBtn: {
    position: 'absolute', bottom: '-4px', right: '-4px', backgroundColor: '#E8865A',
    color: '#fff', width: '24px', height: '24px', borderRadius: '50%',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontSize: '12px', cursor: 'pointer', border: '2px solid #fff',
  },
  primaryBtn: {
    padding: '10px 16px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px',
  },
  secondaryBtn: {
    padding: '10px 16px', backgroundColor: '#eee', color: '#2B2B2B', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px',
  },
  statsGrid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))',
    gap: '12px', marginBottom: '32px',
  },
  statCard: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  statLabel: { fontSize: '12px', fontWeight: 700, margin: '0 0 8px', textTransform: 'uppercase' },
  statValue: { fontSize: '26px', fontWeight: 'bold', margin: 0, color: '#2B2B2B' },
  section: { backgroundColor: '#fff', borderRadius: '12px', padding: '20px' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: '13px' },
  th: { textAlign: 'left', padding: '8px', borderBottom: '2px solid #eee', color: '#8E8E8E' },
  td: { padding: '8px', borderBottom: '1px solid #f5f5f5' },

  qrCard: {
    backgroundColor: '#fff', borderRadius: '16px', padding: '20px',
    marginBottom: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
  },
  qrImage: { width: '120px', height: '120px', border: '1px solid #eee', borderRadius: '8px' },
};