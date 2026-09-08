import { useState, useEffect, useCallback } from 'react';
import {
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import Layout from '../components/Layout';
import reportService from '../services/reportService';

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

const PAYMENT_COLORS = { CASH: '#E8865A', CARD: '#2196F3', MOCK: '#8E8E8E' };

function statusLabel(status) {
  return status.replace(/_/g, ' ').replace(/\w\S*/g, (w) => w[0] + w.slice(1).toLowerCase());
}

function formatDateInput(date) {
  return date.toISOString().split('T')[0];
}

function presetRange(days) {
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - (days - 1));
  return { start: formatDateInput(start), end: formatDateInput(end) };
}

export default function ReportsPage() {
  const [startDate, setStartDate] = useState(presetRange(30).start);
  const [endDate, setEndDate] = useState(presetRange(30).end);
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadReports = useCallback(async () => {
    setLoading(true);
    try {
      const result = await reportService.getReports(startDate, endDate);
      setData(result);
      setError('');
    } catch (err) {
      setError('Failed to load reports.');
    } finally {
      setLoading(false);
    }
  }, [startDate, endDate]);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  const applyPreset = (days) => {
    const range = presetRange(days);
    setStartDate(range.start);
    setEndDate(range.end);
  };

  return (
    <Layout>
      <div style={styles.page}>
        <h1>Reports</h1>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.filterBar}>
          <div style={styles.presetGroup}>
            <button style={styles.presetBtn} onClick={() => applyPreset(7)}>Last 7 Days</button>
            <button style={styles.presetBtn} onClick={() => applyPreset(30)}>Last 30 Days</button>
            <button style={styles.presetBtn} onClick={() => applyPreset(90)}>Last 90 Days</button>
          </div>
          <div style={styles.dateGroup}>
            <input
              type="date"
              value={startDate}
              max={endDate}
              onChange={(e) => setStartDate(e.target.value)}
              style={styles.dateInput}
            />
            <span style={{ color: '#8E8E8E' }}>to</span>
            <input
              type="date"
              value={endDate}
              min={startDate}
              max={formatDateInput(new Date())}
              onChange={(e) => setEndDate(e.target.value)}
              style={styles.dateInput}
            />
          </div>
        </div>

        {loading || !data ? (
          <p style={{ color: '#8E8E8E' }}>Loading...</p>
        ) : (
          <>
            <div style={styles.summaryGrid}>
              <div style={styles.summaryCard}>
                <p style={styles.summaryLabel}>Total Revenue</p>
                <p style={styles.summaryValue}>Rs. {data.summary.total_revenue.toFixed(0)}</p>
              </div>
              <div style={styles.summaryCard}>
                <p style={styles.summaryLabel}>Paid Orders</p>
                <p style={styles.summaryValue}>{data.summary.total_orders}</p>
              </div>
              <div style={styles.summaryCard}>
                <p style={styles.summaryLabel}>Avg. Order Value</p>
                <p style={styles.summaryValue}>Rs. {data.summary.avg_order_value.toFixed(0)}</p>
              </div>
            </div>

            <div style={styles.chartCard}>
              <h3 style={styles.chartTitle}>Revenue Over Time</h3>
              <ResponsiveContainer width="100%" height={280}>
                <LineChart data={data.revenue_by_day}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip formatter={(value) => [`Rs. ${value.toFixed(0)}`, 'Revenue']} />
                  <Line type="monotone" dataKey="revenue" stroke="#E8865A" strokeWidth={2} dot={{ r: 3 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>

            <div style={styles.chartCard}>
              <h3 style={styles.chartTitle}>Order Volume</h3>
              <ResponsiveContainer width="100%" height={260}>
                <BarChart data={data.volume_by_day}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
                  <Tooltip />
                  <Legend wrapperStyle={{ fontSize: '12px' }} />
                  <Bar dataKey="order_count" name="Orders" fill="#2B2B2B" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="unique_customers" name="Unique Customers" fill="#E8865A" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>

            <div style={styles.twoCol}>
              <div style={styles.chartCard}>
                <h3 style={styles.chartTitle}>Order Status Breakdown</h3>
                <ResponsiveContainer width="100%" height={260}>
                  <PieChart>
                    <Pie
                      data={data.status_breakdown}
                      dataKey="count"
                      nameKey="status"
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      label={({ status, count }) => `${statusLabel(status)}: ${count}`}
                      labelLine={false}
                    >
                      {data.status_breakdown.map((entry) => (
                        <Cell key={entry.status} fill={STATUS_COLORS[entry.status] || '#999'} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(value, name, props) => [value, statusLabel(props.payload.status)]} />
                  </PieChart>
                </ResponsiveContainer>
              </div>

              <div style={styles.chartCard}>
                <h3 style={styles.chartTitle}>Payment Method Breakdown</h3>
                {data.payment_breakdown.length === 0 ? (
                  <p style={{ color: '#8E8E8E', fontSize: '13px' }}>No completed payments in this range.</p>
                ) : (
                  <ResponsiveContainer width="100%" height={260}>
                    <PieChart>
                      <Pie
                        data={data.payment_breakdown}
                        dataKey="total"
                        nameKey="method"
                        cx="50%"
                        cy="50%"
                        outerRadius={80}
                        label={({ method, total }) => `${method}: Rs. ${total.toFixed(0)}`}
                        labelLine={false}
                      >
                        {data.payment_breakdown.map((entry) => (
                          <Cell key={entry.method} fill={PAYMENT_COLORS[entry.method] || '#999'} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(value) => `Rs. ${value.toFixed(0)}`} />
                    </PieChart>
                  </ResponsiveContainer>
                )}
              </div>
            </div>

            <div style={styles.chartCard}>
              <h3 style={styles.chartTitle}>Best-Selling Items</h3>
              {data.top_items.length === 0 ? (
                <p style={{ color: '#8E8E8E', fontSize: '13px' }}>No item sales in this range.</p>
              ) : (
                <table style={styles.table}>
                  <thead>
                    <tr>
                      <th style={styles.th}>Item</th>
                      <th style={styles.th}>Quantity Sold</th>
                      <th style={styles.th}>Revenue</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.top_items.map((item, idx) => (
                      <tr key={idx}>
                        <td style={styles.td}>{item.item_name}</td>
                        <td style={styles.td}>{item.quantity_sold}</td>
                        <td style={styles.td}>Rs. {item.revenue.toFixed(0)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  page: { padding: '32px', maxWidth: '1100px' },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  filterBar: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    flexWrap: 'wrap', gap: '12px', marginBottom: '24px',
  },
  presetGroup: { display: 'flex', gap: '8px' },
  presetBtn: {
    padding: '8px 14px', border: '1px solid #ddd', borderRadius: '20px',
    backgroundColor: '#fff', cursor: 'pointer', fontSize: '13px',
  },
  dateGroup: { display: 'flex', alignItems: 'center', gap: '8px' },
  dateInput: {
    padding: '8px 10px', border: '1px solid #ddd', borderRadius: '8px', fontSize: '13px',
  },
  summaryGrid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
    gap: '16px', marginBottom: '24px',
  },
  summaryCard: {
    backgroundColor: '#fff', borderRadius: '12px', padding: '18px',
  },
  summaryLabel: { fontSize: '12px', color: '#8E8E8E', margin: '0 0 6px' },
  summaryValue: { fontSize: '24px', fontWeight: 700, margin: 0, color: '#2B2B2B' },
  chartCard: {
    backgroundColor: '#fff', borderRadius: '12px', padding: '20px', marginBottom: '20px',
  },
  chartTitle: { fontSize: '15px', fontWeight: 600, margin: '0 0 16px' },
  twoCol: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '20px',
  },
  table: { width: '100%', borderCollapse: 'collapse' },
  th: {
    textAlign: 'left', fontSize: '12px', color: '#8E8E8E', fontWeight: 600,
    padding: '8px 4px', borderBottom: '1px solid #eee',
  },
  td: { padding: '10px 4px', fontSize: '13px', borderBottom: '1px solid #f5f5f5' },
};