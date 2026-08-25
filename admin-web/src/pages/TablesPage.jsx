import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import tableSessionService from '../services/tableSessionService';

const STATUS_INFO = {
  OPEN: { label: 'Open', color: '#2196F3' },
  PAYMENT_PENDING: { label: 'Payment Pending', color: '#FB8C00' },
  PAID: { label: 'Paid', color: '#4CAF50' },
  CLOSED: { label: 'Closed', color: '#8E8E8E' },
};

export default function TablesPage() {
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('CURRENT');
  const [confirmingId, setConfirmingId] = useState(null);

  useEffect(() => {
    loadSessions();
    const interval = setInterval(loadSessions, 15000);
    return () => clearInterval(interval);
  }, []);

  const loadSessions = async () => {
    try {
      const data = await tableSessionService.getSessions();
      setSessions(data);
      setError('');
    } catch (err) {
      setError('Failed to load tables.');
    } finally {
      setLoading(false);
    }
  };

  const handleConfirmPayment = async (session) => {
    if (!confirm(`Confirm you have received Rs. ${parseFloat(session.total_amount).toFixed(0)} cash for Table ${session.table_number}?`)) return;
    setConfirmingId(session.id);
    try {
      await tableSessionService.confirmPayment(session.id);
      loadSessions();
    } catch (err) {
      setError('Failed to confirm payment.');
    } finally {
      setConfirmingId(null);
    }
  };

  const filtered = sessions.filter((s) => {
    if (filter === 'CURRENT') return s.status === 'OPEN' || s.status === 'PAYMENT_PENDING';
    if (filter === 'ALL') return true;
    return s.status === filter;
  });

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  return (
    <Layout>
      <div style={styles.page}>
        <h1>Tables</h1>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.filters}>
          {['CURRENT', 'ALL', 'OPEN', 'PAYMENT_PENDING', 'PAID', 'CLOSED'].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              style={{
                ...styles.filterBtn,
                backgroundColor: filter === f ? '#E8865A' : '#fff',
                color: filter === f ? '#fff' : '#2B2B2B',
              }}
            >
              {f === 'CURRENT' ? 'Current' : f === 'ALL' ? 'All' : STATUS_INFO[f]?.label || f}
            </button>
          ))}
        </div>

        {filtered.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No tables in this category.</p>
        ) : (
          <div style={styles.grid}>
            {filtered.map((session) => {
              const info = STATUS_INFO[session.status] || { label: session.status, color: '#999' };
              return (
                <div key={session.id} style={styles.card}>
                  <div style={styles.cardHeader}>
                    <div>
                      <strong style={{ fontSize: '18px' }}>Table {session.table_number}</strong>
                      <p style={{ margin: '2px 0 0', fontSize: '12px', color: '#8E8E8E' }}>
                        {session.customer_username}
                      </p>
                      {session.from_reservation && (
                        <span style={styles.reservationTag}>
                          Reservation #{session.from_reservation}
                        </span>
                      )}
                    </div>
                    <span style={{ ...styles.badge, backgroundColor: `${info.color}22`, color: info.color }}>
                      {info.label}
                    </span>
                  </div>

                  <div style={styles.ordersBox}>
                    {session.orders.map((order) => (
                      <div key={order.id} style={{ marginBottom: '10px' }}>
                        <p style={{ margin: '0 0 4px', fontSize: '13px', fontWeight: 600 }}>
                          Order #{order.id} — {order.status}
                        </p>
                        {order.items.map((item) => (
                          <div key={item.id} style={styles.itemRow}>
                            <span>{item.quantity}x {item.item_name}{item.variant_name ? ` (${item.variant_name})` : ''}</span>
                            <span>Rs. {parseFloat(item.subtotal).toFixed(0)}</span>
                          </div>
                        ))}
                      </div>
                    ))}
                  </div>

                  <div style={styles.totalRow}>
                    <strong>Total Bill</strong>
                    <strong>Rs. {parseFloat(session.total_amount).toFixed(0)}</strong>
                  </div>

                  {session.status === 'PAYMENT_PENDING' && (
                    <button
                      style={styles.confirmBtn}
                      disabled={confirmingId === session.id}
                      onClick={() => handleConfirmPayment(session)}
                    >
                      {confirmingId === session.id ? 'Confirming...' : 'Confirm Cash Payment Received'}
                    </button>
                  )}
                </div>
              );
            })}
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
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px' },
  card: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' },
  badge: { padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 700 },
  ordersBox: { borderTop: '1px solid #f0f0f0', borderBottom: '1px solid #f0f0f0', padding: '10px 0', marginBottom: '10px' },
  itemRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginLeft: '8px', marginBottom: '2px' },
  totalRow: { display: 'flex', justifyContent: 'space-between', fontSize: '15px', marginBottom: '10px' },
  confirmBtn: {
    width: '100%', padding: '10px', backgroundColor: '#FB8C00', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: 600,
  },
    reservationTag: {
    display: 'inline-block',
    marginTop: '6px',
    padding: '2px 8px',
    backgroundColor: '#EDE7F6',
    color: '#673AB7',
    borderRadius: '12px',
    fontSize: '11px',
    fontWeight: 600,
  },
};