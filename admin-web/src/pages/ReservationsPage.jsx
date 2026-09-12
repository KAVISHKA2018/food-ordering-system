import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import reservationService from '../services/reservationService';
import tableSessionService from '../services/tableSessionService';

const STATUS_COLORS = {
  PENDING: '#FF9800',
  CONFIRMED: '#2196F3',
  SEATED: '#009688',
  COMPLETED: '#4CAF50',
  CANCELLED: '#E53935',
  NO_SHOW: '#795548',
};

const PAYMENT_INFO = {
  UNPAID: { label: 'Unpaid', color: '#8E8E8E' },
  PENDING_CONFIRMATION: { label: 'Payment Pending Confirmation', color: '#FB8C00' },
  PAID: { label: 'Paid', color: '#4CAF50' },
};

function statusLabel(status) {
  return status.replace(/_/g, ' ').replace(/\w\S*/g, (w) => w[0] + w.slice(1).toLowerCase());
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString(undefined, { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' });
}

function formatTime(timeStr) {
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
  const [tableInputs, setTableInputs] = useState({}); // { [reservationId]: "value being typed" }

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

  const handleAssignTable = async (reservation) => {
    const value = (tableInputs[reservation.id] ?? reservation.table_number ?? '').trim();
    if (!value) {
      setError('Please enter a table number.');
      return;
    }
    setUpdatingId(reservation.id);
    try {
      await reservationService.assignTable(reservation.id, value);
      loadReservations();
    } catch (err) {
      setError('Failed to assign table.');
    } finally {
      setUpdatingId(null);
    }
  };

  const handleStatusChange = async (reservation, newStatus) => {
    setUpdatingId(reservation.id);
    try {
      await reservationService.updateStatus(reservation.id, newStatus);
      loadReservations();
    } catch (err) {
      const msg = err.response?.data?.detail || 'Failed to update reservation status.';
      setError(msg);
    } finally {
      setUpdatingId(null);
    }
  };

  const handleConfirmPayment = async (reservation) => {
    if (!reservation.table_session) return;
    if (!confirm(`Confirm cash payment received for this reservation's table?`)) return;
    setUpdatingId(reservation.id);
    try {
      await tableSessionService.confirmPayment(reservation.table_session);
      loadReservations();
    } catch (err) {
      setError('Failed to confirm payment.');
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
        return resDate >= today && !['SEATED', 'CANCELLED', 'COMPLETED', 'NO_SHOW'].includes(r.status);
      }
      return r.status === filter;
    })
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  const STATUS_OPTIONS = ['PENDING', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'];

  return (
    <Layout>
      <div style={styles.page}>
        <h1>Reservations</h1>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.filters}>
          {['UPCOMING', 'ALL', ...STATUS_OPTIONS].map((s) => {
            let count = 0;
            if (s === 'SEATED') {
              count = reservations.filter((r) => r.status === 'SEATED').length;
            } else if (s === 'UPCOMING') {
              count = reservations.filter((r) => {
                const resDate = new Date(r.reservation_date);
                return resDate >= today && !['SEATED', 'CANCELLED', 'COMPLETED', 'NO_SHOW'].includes(r.status);
              }).length;
            }

            return (
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
                {count > 0 && (
                  <span
                    style={{
                      ...styles.filterBadge,
                      backgroundColor: filter === s ? 'rgba(255,255,255,0.3)' : '#E53935',
                      color: '#fff',
                    }}
                  >
                    {count}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {filteredReservations.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No reservations in this category.</p>
        ) : (
          <div style={styles.grid}>
            {filteredReservations.map((res) => {
              const paymentInfo = PAYMENT_INFO[res.payment_status];
              const isUpdating = updatingId === res.id;
              const canEditTable = ['PENDING', 'CONFIRMED'].includes(res.status);

              return (
                <div key={res.id} style={styles.card}>
                  <div style={styles.cardHeader}>
                    <div>
                      <div style={{ fontSize: '12px', color: '#8E8E8E', fontWeight: 600 }}>
                        Reservation #{res.id}
                      </div>
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
                      <p style={styles.preOrderTitle}>Original Pre-Order</p>
                      {res.pre_order_items.map((item) => (
                        <div key={item.id} style={styles.itemRow}>
                          <span>{item.quantity}x {item.item_name}</span>
                          <span>Rs. {parseFloat(item.subtotal).toFixed(0)}</span>
                        </div>
                      ))}
                      <div style={styles.totalRow}>
                        <span>Pre-Order Subtotal</span>
                        <span>Rs. {parseFloat(res.pre_order_total).toFixed(0)}</span>
                      </div>
                    </div>
                  )}

                  {res.table_session && (
                    <div style={styles.billBox}>
                      <div style={styles.totalRow}>
                        <strong>Current Table Bill</strong>
                        <strong>Rs. {parseFloat(res.current_bill_total).toFixed(0)}</strong>
                      </div>
                      <p style={{ margin: '2px 0 0', fontSize: '11px', color: '#8E8E8E' }}>
                        Includes pre-order + any food added after seating
                      </p>
                    </div>
                  )}

                  {/* Table assignment */}
                  <div style={styles.tableSection}>
                    <label style={styles.smallLabel}>Table Number</label>
                    {canEditTable ? (
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <input
                          style={styles.tableInput}
                          placeholder="e.g. 07"
                          value={tableInputs[res.id] ?? res.table_number ?? ''}
                          onChange={(e) =>
                            setTableInputs({ ...tableInputs, [res.id]: e.target.value })
                          }
                        />
                        <button
                          style={styles.assignBtn}
                          disabled={isUpdating}
                          onClick={() => handleAssignTable(res)}
                        >
                          {res.table_number ? 'Update' : 'Assign'}
                        </button>
                      </div>
                    ) : (
                      <p style={{ margin: 0, fontWeight: 600 }}>
                        {res.table_number ? `Table ${res.table_number}` : '—'}
                      </p>
                    )}
                  </div>

                  {/* Payment status (only shown once seated / table session exists) */}
                  {paymentInfo && (
                    <div style={{ marginTop: '10px' }}>
                      <span
                        style={{
                          ...styles.badge,
                          backgroundColor: `${paymentInfo.color}22`,
                          color: paymentInfo.color,
                        }}
                      >
                        {paymentInfo.label}
                      </span>
                      {res.payment_method && (
                        <p style={styles.paymentNote}>
                          {res.payment_method === 'CARD' ? '💳 Card Payment' : '💵 Cash Payment'}
                        </p>
                      )}
                      {res.payment_status === 'PENDING_CONFIRMATION' && (
                        <button
                          style={styles.confirmPaymentBtn}
                          disabled={isUpdating}
                          onClick={() => handleConfirmPayment(res)}
                        >
                          {isUpdating ? 'Confirming...' : 'Confirm Cash Payment Received'}
                        </button>
                      )}
                    </div>
                  )}

                  {/* Status action buttons */}
                  {!['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(res.status) && (
                    <div style={styles.actions}>
                      {res.status === 'PENDING' && (
                        <button
                          style={{
                            ...styles.primaryBtn,
                            ...(res.table_number ? {} : styles.primaryBtnDisabled),
                          }}
                          disabled={isUpdating || !res.table_number}
                          title={!res.table_number ? 'Assign a table before confirming' : ''}
                          onClick={() => handleStatusChange(res, 'CONFIRMED')}
                        >
                          {res.table_number ? 'Confirm' : 'Assign table to confirm'}
                        </button>
                      )}
                      {res.status === 'CONFIRMED' && (
                        <button
                          style={styles.primaryBtn}
                          disabled={isUpdating}
                          onClick={() => handleStatusChange(res, 'SEATED')}
                        >
                          Mark Seated
                        </button>
                      )}
                      <button
                        style={styles.cancelBtn}
                        disabled={isUpdating}
                        onClick={() => handleStatusChange(res, 'CANCELLED')}
                      >
                        Cancel
                      </button>
                    </div>
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
    display: 'inline-flex', alignItems: 'center', gap: '6px',
  },
  filterBadge: {
    borderRadius: '10px',
    fontSize: '11px',
    fontWeight: 700,
    padding: '1px 6px',
    minWidth: '16px',
    textAlign: 'center',
    lineHeight: 1.4,
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
  tableSection: { marginTop: '12px', paddingTop: '12px', borderTop: '1px solid #f0f0f0' },
  smallLabel: { fontSize: '11px', fontWeight: 700, color: '#8E8E8E', display: 'block', marginBottom: '4px' },
  tableInput: {
    flex: 1, padding: '8px', borderRadius: '6px', border: '1px solid #ddd', fontSize: '13px',
  },
  assignBtn: {
    padding: '8px 12px', backgroundColor: '#2B2B2B', color: '#fff', border: 'none',
    borderRadius: '6px', cursor: 'pointer', fontSize: '12px',
  },
  paymentNote: {
    fontSize: '12px', color: '#8E8E8E', margin: '6px 0 0',
  },
  confirmPaymentBtn: {
    display: 'block', width: '100%', padding: '9px', backgroundColor: '#FB8C00', color: '#fff',
    border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '12px', fontWeight: 600, marginTop: '8px',
  },
  actions: { display: 'flex', gap: '6px', marginTop: '14px', flexWrap: 'wrap' },
  primaryBtn: {
    flex: 1, padding: '9px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '12px', minWidth: '90px',
  },
  primaryBtnDisabled: {
    backgroundColor: '#ddd', color: '#888', cursor: 'not-allowed',
  },
  secondaryActionBtn: {
    padding: '9px 12px', backgroundColor: '#fff', color: '#795548', border: '1px solid #795548',
    borderRadius: '8px', cursor: 'pointer', fontSize: '12px',
  },
  cancelBtn: {
    padding: '9px 12px', backgroundColor: '#fff', color: '#E53935', border: '1px solid #E53935',
    borderRadius: '8px', cursor: 'pointer', fontSize: '12px',
  },
    billBox: {
    backgroundColor: '#EEF7ED', borderRadius: '8px', padding: '10px', marginTop: '10px',
  },

};