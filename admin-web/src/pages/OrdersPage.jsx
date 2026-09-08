import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import orderService from '../services/orderService';
import DeliveryLocationMap from '../components/DeliveryLocationMap';

const STATUS_COLORS = {
  AWAITING_PAYMENT: '#E53935',
  PAYMENT_PENDING: '#FB8C00',
  PENDING: '#FF9800',
  CONFIRMED: '#2196F3',
  PREPARING: '#9C27B0',
  READY: '#009688',
  OUT_FOR_DELIVERY: '#3F51B5',
  COMPLETED: '#4CAF50',
  CANCELLED: '#E53935',
};

function statusLabel(status) {
  return status.replace(/_/g, ' ').replace(/\w\S*/g, (w) => w[0] + w.slice(1).toLowerCase());
}

function getFlow(orderType) {
  if (orderType === 'DELIVERY') {
    return ['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY', 'COMPLETED'];
  }
  // Dine-in and Takeaway never go through delivery
  return ['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'COMPLETED'];
}

function nextStatus(order) {
  const flow = getFlow(order.order_type);
  const idx = flow.indexOf(order.status);
  if (idx === -1 || idx === flow.length - 1) return null;
  return flow[idx + 1];
}

export default function OrdersPage() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('ALL');
  const [updatingId, setUpdatingId] = useState(null);

  useEffect(() => {
    loadOrders();
    const interval = setInterval(loadOrders, 15000);
    return () => clearInterval(interval);
  }, []);

  const loadOrders = async () => {
    try {
      const data = await orderService.getOrders();
      setOrders(data);
      setError('');
    } catch (err) {
      setError('Failed to load orders.');
    } finally {
      setLoading(false);
    }
  };

  const handleAdvance = async (order) => {
    const next = nextStatus(order);
    if (!next) return;
    setUpdatingId(order.id);
    try {
      await orderService.updateStatus(order.id, next);
      loadOrders();
    } catch (err) {
      setError('Failed to update order status.');
    } finally {
      setUpdatingId(null);
    }
  };

  const handleCancel = async (order) => {
    if (!confirm(`Cancel order #${order.id}?`)) return;
    setUpdatingId(order.id);
    try {
      await orderService.updateStatus(order.id, 'CANCELLED');
      loadOrders();
    } catch (err) {
      setError('Failed to cancel order.');
    } finally {
      setUpdatingId(null);
    }
  };

  const handleConfirmPayment = async (order) => {
    if (!confirm(`Confirm you have received Rs. ${parseFloat(order.total_amount).toFixed(0)} cash for order #${order.id}?`)) return;
    setUpdatingId(order.id);
    try {
      await orderService.confirmPayment(order.id);
      loadOrders();
    } catch (err) {
      setError('Failed to confirm payment.');
    } finally {
      setUpdatingId(null);
    }
  };

  const filteredOrders = orders
    .filter((o) => filter === 'ALL' || o.status === filter)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  const allStatuses = ['ALL', 'AWAITING_PAYMENT', 'PAYMENT_PENDING', 'PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY', 'COMPLETED', 'CANCELLED'];

  return (
    <Layout>
      <div style={styles.page}>
        <h1>Orders</h1>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.filters}>
          {allStatuses.map((s) => (
            <button
              key={s}
              onClick={() => setFilter(s)}
              style={{
                ...styles.filterBtn,
                backgroundColor: filter === s ? '#E8865A' : '#fff',
                color: filter === s ? '#fff' : '#2B2B2B',
              }}
            >
              {s === 'ALL' ? 'All' : statusLabel(s)}
            </button>
          ))}
        </div>

        {filteredOrders.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No orders in this category.</p>
        ) : (
          <div style={styles.grid}>
            {filteredOrders.map((order) => {
              const next = nextStatus(order);
              const isFinal = order.status === 'COMPLETED' || order.status === 'CANCELLED';
              const needsPaymentConfirmation = order.status === 'PAYMENT_PENDING';
              const isAwaitingCustomerPayment = order.status === 'AWAITING_PAYMENT';

              return (
                <div key={order.id} style={styles.card}>
                  <div style={styles.cardHeader}>
                    <strong>Order #{order.id}</strong>
                    <span
                      style={{
                        ...styles.badge,
                        backgroundColor: `${STATUS_COLORS[order.status] || '#999'}22`,
                        color: STATUS_COLORS[order.status] || '#999',
                      }}
                    >
                      {statusLabel(order.status)}
                    </span>
                  </div>
                  <p style={styles.meta}>
                    {order.customer_username} · {statusLabel(order.order_type)}
                    {order.table_number ? ` · Table ${order.table_number}` : ''} ·{' '}
                    {new Date(order.created_at).toLocaleString()}
                  </p>

                  {order.order_type === 'DELIVERY' && (order.delivery_address || order.contact_phone) && (
                    <div style={styles.deliveryBox}>
                      {order.delivery_address && <p style={styles.smallNote}>Address: {order.delivery_address}</p>}
                      {order.contact_phone && <p style={styles.smallNote}>Phone: {order.contact_phone}</p>}
                      {order.alternative_phone && <p style={styles.smallNote}>Phone 2: (Alt) {order.alternative_phone}</p>}
                      {order.delivery_latitude && order.delivery_longitude && (
                        <div style={{ marginTop: '8px' }}>
                          <DeliveryLocationMap
                            latitude={order.delivery_latitude}
                            longitude={order.delivery_longitude}
                            orderId={order.id}
                          />

                          <a                            
                            href={`https://www.openstreetmap.org/?mlat=${order.delivery_latitude}&mlon=${order.delivery_longitude}#map=17/${order.delivery_latitude}/${order.delivery_longitude}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            style={styles.mapLink}
                          >
                            🗺️ Open Full Map
                          </a>
                        </div>
                      )}
                    </div>
                  )}
                  
                  <div style={styles.itemsList}>
                    {order.items.map((item) => (
                      <div key={item.id} style={styles.itemRow}>
                        <span>{item.quantity}x {item.item_name}{item.variant_name ? ` (${item.variant_name})` : ''}</span>
                        <span>Rs. {parseFloat(item.subtotal).toFixed(0)}</span>
                      </div>
                    ))}
                  </div>

                  {order.notes && <p style={styles.smallNote}>📝 {order.notes}</p>}

                  {order.promotion_title && (
                    <p style={styles.promoNote}>🏷️ {order.promotion_title}</p>
                  )}

                  <div style={styles.itemRow}>
                    <span>Subtotal</span>
                    <span>Rs. {parseFloat(order.subtotal_amount ?? order.total_amount).toFixed(0)}</span>
                  </div>

                  {parseFloat(order.discount_amount) > 0 && (
                    <div style={{ ...styles.itemRow, color: '#4CAF50' }}>
                      <span>Discount</span>
                      <span>-Rs. {parseFloat(order.discount_amount).toFixed(0)}</span>
                    </div>
                  )}

                  <div style={styles.totalRow}>
                    <strong>Total</strong>
                    <strong>Rs. {parseFloat(order.total_amount).toFixed(0)}</strong>
                  </div>

                  {order.payment_method && (
                    <p style={styles.smallNote}>
                      {order.payment_method === 'CARD' ? '💳 Card Payment' : '💵 Cash Payment'}
                    </p>
                  )}

                  {order.order_type === 'TAKEAWAY' && (
                    <p style={{ ...styles.smallNote, fontWeight: 600 }}>
                      Payment: {order.payment_status === 'PAID' ? '✅ Paid' :
                        order.payment_status === 'PENDING_CONFIRMATION' ? '🟠 Awaiting confirmation' : '❌ Unpaid'}
                    </p>
                  )}

                  {needsPaymentConfirmation && (
                    <button
                      style={styles.confirmPaymentBtn}
                      disabled={updatingId === order.id}
                      onClick={() => handleConfirmPayment(order)}
                    >
                      {updatingId === order.id ? 'Confirming...' : 'Confirm Cash Payment Received'}
                    </button>
                  )}

                  {isAwaitingCustomerPayment && (
                    <p style={styles.smallNote}>Waiting for customer to pay...</p>
                  )}

                  {!isFinal && !needsPaymentConfirmation && !isAwaitingCustomerPayment && (
                    <div style={styles.actions}>
                      {next && (
                        <button
                          style={styles.primaryBtn}
                          disabled={updatingId === order.id}
                          onClick={() => handleAdvance(order)}
                        >
                          {updatingId === order.id ? 'Updating...' : `Mark as ${statusLabel(next)}`}
                        </button>
                      )}
                      <button
                        style={styles.cancelBtn}
                        disabled={updatingId === order.id}
                        onClick={() => handleCancel(order)}
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
  },
  grid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px',
  },
  card: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' },
  badge: { padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 700 },
  meta: { fontSize: '12px', color: '#8E8E8E', marginBottom: '12px' },
  deliveryBox: { backgroundColor: '#F5F5F5', borderRadius: '8px', padding: '8px', marginBottom: '10px' },
  itemsList: { borderTop: '1px solid #f0f0f0', borderBottom: '1px solid #f0f0f0', padding: '10px 0', marginBottom: '10px' },
  itemRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' },
  smallNote: { fontSize: '12px', color: '#8E8E8E', margin: '4px 0' },
  totalRow: { display: 'flex', justifyContent: 'space-between', fontSize: '14px', margin: '10px 0' },
  actions: { display: 'flex', gap: '8px', marginTop: '12px' },
  primaryBtn: {
    flex: 1, padding: '10px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px',
  },
  cancelBtn: {
    padding: '10px 14px', backgroundColor: '#fff', color: '#E53935', border: '1px solid #E53935',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px',
  },
  confirmPaymentBtn: {
    width: '100%', padding: '10px', backgroundColor: '#FB8C00', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px', marginTop: '10px', fontWeight: 600,
  },
  promoNote: {
    fontSize: '12px', color: '#E8865A', margin: '6px 0', fontWeight: 600,
  },
  mapEmbed: {
    border: 0, borderRadius: '8px', marginBottom: '6px', display: 'block',
  },
  mapLink: {
    display: 'inline-block', marginTop: '4px', fontSize: '12px', color: '#2196F3',
    fontWeight: 600, textDecoration: 'none',
  },
};