import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import reservationService from '../services/reservationService';

const STATUS_COLORS = {
  PENDING: '#FF9800',
  CONFIRMED: '#2196F3',
  SEATED: '#009688',
  COMPLETED: '#4CAF50',
  CANCELLED: '#E53935',
  NO_SHOW: '#795548',
};

const STATUS_OPTIONS = ['PENDING', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'];

function statusLabel(status) {
  return status.replace(/_/g, ' ').replace(/\w\S*/g, (w) => w[0] + w.slice(1).toLowerCase());
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString(undefined, { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' });
}

function formatTime(timeStr) {
  // timeStr comes as "HH:MM:SS" from Django's TimeField
  const [h, m] = timeStr.split(':');
  const hour = parseInt(h, 10);
  const period = hour >= 12 ? 'PM' : 'AM';
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${hour12}:${m} ${period}`;
}

export default function ReservationsPage() {
  const [reservations, setReservations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('UPCOMING');
  const [updatingId, setUpdatingId] = useState(null);

  useEffect(() => {
    loadReservations();
    const interval = setInterval(loadReservations, 20000);
    return () => clearInterval(interval);
  }, []);

  const loadReservations = async () => {
    try {
      const data = await reservationService.getReservations();
      setReservations(data);
      setError('');
    } catch (err) {
      setError('Failed to load reservations.');
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (reservation, newStatus) => {
    setUpdatingId(reservation.id);
    try {
      await reservationService.updateStatus(reservation.id, newStatus);
      loadReservations();
    } catch (err) {
      setError('Failed to update reservation status.');
    } finally {
      setUpdatingId(null);
    }
  };

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const filteredReservations = reservations
    .filter((r) => {
      if (filter === 'ALL') return true;
      if (filter === 'UPCOMING') {
        const resDate = new Date(r.reservation_date);
        return resDate >= today && !['CANCELLED', 'COMPLETED', 'NO_SHOW'].includes(r.status);
      }
      return r.status === filter;
    })
    .sort((a, b) => {
      const dateCompare = new Date(a.reservation_date) - new Date(b.reservation_date);
      if (dateCompare !== 0) return dateCompare;
      return a.reservation_time.localeCompare(b.reservation_time);
    });

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  return (
    <Layout>
      <div style={styles.page}>
        <h1>Reservations</h1>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.filters}>
          {['UPCOMING', 'ALL', ...STATUS_OPTIONS].map((s) => (
            <button
              key={s}
              onClick={() => setFilter(s)}
              style={{
                ...styles.filterBtn,
                backgroundColor: filter === s ? '#E8865A' : '#fff',
                color: filter === s ? '#fff' : '#2B2B2B',
              }}
            >
              {s === 'ALL' ? 'All' : s === 'UPCOMING' ? 'Upcoming' : statusLabel(s)}
            </button>
          ))}
        </div>

        {filteredReservations.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No reservations in this category.</p>
        ) : (
          <div style={styles.grid}>
            {filteredReservations.map((res) => (
              <div key={res.id} style={styles.card}>
                <div style={styles.cardHeader}>
                  <div>
                    <strong style={{ fontSize: '16px' }}>{formatDate(res.reservation_date)}</strong>
                    <div style={{ fontSize: '14px', color: '#8E8E8E' }}>{formatTime(res.reservation_time)}</div>
                  </div>
                  <span
                    style={{
                      ...styles.badge,
                      backgroundColor: `${STATUS_COLORS[res.status]}22`,
                      color: STATUS_COLORS[res.status],
                    }}
                  >
                    {statusLabel(res.status)}
                  </span>
                </div>

                <div style={styles.infoRow}>
                  <span>👤 {res.customer_username}</span>
                  <span>👥 {res.party_size} {res.party_size === 1 ? 'guest' : 'guests'}</span>
                </div>

                {res.special_requests && (
                  <p style={styles.smallNote}>📝 {res.special_requests}</p>
                )}

                {res.pre_order_items?.length > 0 && (
                  <div style={styles.preOrderBox}>
                    <p style={styles.preOrderTitle}>Pre-Order</p>
                    {res.pre_order_items.map((item) => (
                      <div key={item.id} style={styles.itemRow}>
                        <span>{item.quantity}x {item.item_name}</span>
                        <span>Rs. {parseFloat(item.subtotal).toFixed(0)}</span>
                      </div>
                    ))}
                    <div style={styles.totalRow}>
                      <strong>Pre-Order Total</strong>
                      <strong>Rs. {parseFloat(res.pre_order_total).toFixed(0)}</strong>
                    </div>
                  </div>
                )}

                {!['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(res.status) && (
                  <div style={styles.actions}>
                    {res.status === 'PENDING' && (
                      <button
                        style={styles.primaryBtn}
                        disabled={updatingId === res.id}
                        onClick={() => handleStatusChange(res, 'CONFIRMED')}
                      >
                        Confirm
                      </button>
                    )}
                    {res.status === 'CONFIRMED' && (
                      <button
                        style={styles.primaryBtn}
                        disabled={updatingId === res.id}
                        onClick={() => handleStatusChange(res, 'SEATED')}
                      >
                        Mark Seated
                      </button>
                    )}
                    {res.status === 'SEATED' && (
                      <button
                        style={styles.primaryBtn}
                        disabled={updatingId === res.id}
                        onClick={() => handleStatusChange(res, 'COMPLETED')}
                      >
                        Mark Completed
                      </button>
                    )}
                    <button
                      style={styles.secondaryActionBtn}
                      disabled={updatingId === res.id}
                      onClick={() => handleStatusChange(res, 'NO_SHOW')}
                    >
                      No Show
                    </button>
                    <button
                      style={styles.cancelBtn}
                      disabled={updatingId === res.id}
                      onClick={() => handleStatusChange(res, 'CANCELLED')}
                    >
                      Cancel
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  page: { padding: '32px', maxWidth: '1100px' },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  filters: { display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '24px' },
  filterBtn: {
    padding: '8px 14px', border: '1px solid #ddd', borderRadius: '20px', cursor: 'pointer', fontSize: '13px',
  },
  grid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px',
  },
  card: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' },
  badge: { padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 700, whiteSpace: 'nowrap' },
  infoRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#2B2B2B', marginBottom: '8px' },
  smallNote: { fontSize: '12px', color: '#8E8E8E', margin: '6px 0' },
  preOrderBox: { backgroundColor: '#FFF8F3', borderRadius: '8px', padding: '10px', marginTop: '10px' },
  preOrderTitle: { fontSize: '12px', fontWeight: 700, color: '#E8865A', margin: '0 0 6px' },
  itemRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' },
  totalRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginTop: '6px', borderTop: '1px solid #eee', paddingTop: '6px' },
  actions: { display: 'flex', gap: '6px', marginTop: '14px', flexWrap: 'wrap' },
  primaryBtn: {
    flex: 1, padding: '9px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '12px', minWidth: '90px',
  },
  secondaryActionBtn: {
    padding: '9px 12px', backgroundColor: '#fff', color: '#795548', border: '1px solid #795548',
    borderRadius: '8px', cursor: 'pointer', fontSize: '12px',
  },
  cancelBtn: {
    padding: '9px 12px', backgroundColor: '#fff', color: '#E53935', border: '1px solid #E53935',
    borderRadius: '8px', cursor: 'pointer', fontSize: '12px',
  },
};