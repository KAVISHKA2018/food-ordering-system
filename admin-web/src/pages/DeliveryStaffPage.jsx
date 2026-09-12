import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import deliveryStaffService from '../services/deliveryStaffService';

export default function DeliveryStaffPage() {
  const [staff, setStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [creating, setCreating] = useState(false);
  const [toggling, setToggling] = useState(null);

  const [form, setForm] = useState({
    firstName: '', lastName: '', username: '', password: '', phoneNumber: '',
  });

  useEffect(() => {
    loadStaff();
  }, []);

  const loadStaff = async () => {
    try {
      const data = await deliveryStaffService.getMyStaff();
      setStaff(data);
      setError('');
    } catch (err) {
      setError('Failed to load delivery staff.');
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    setCreating(true);
    setError('');
    try {
      await deliveryStaffService.createStaff(form);
      setForm({ firstName: '', lastName: '', username: '', password: '', phoneNumber: '' });
      setShowForm(false);
      loadStaff();
    } catch (err) {
      const data = err.response?.data;
      const message = data ? Object.values(data)[0] : 'Failed to create rider.';
      setError(Array.isArray(message) ? message[0] : message.toString());
    } finally {
      setCreating(false);
    }
  };

  const handleToggle = async (staffId) => {
    setToggling(staffId);
    try {
      await deliveryStaffService.toggleActive(staffId);
      loadStaff();
    } catch (err) {
      setError('Failed to update rider status.');
    } finally {
      setToggling(null);
    }
  };

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  return (
    <Layout>
      <div style={styles.page}>
        <div style={styles.header}>
          <h1>Delivery Staff</h1>
          <button style={styles.addBtn} onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancel' : '+ Add Rider'}
          </button>
        </div>

        {error && <div style={styles.error}>{error}</div>}

        {showForm && (
          <form onSubmit={handleCreate} style={styles.form}>
            <div style={styles.formGrid}>
              <input
                placeholder="First Name"
                value={form.firstName}
                onChange={(e) => setForm({ ...form, firstName: e.target.value })}
                required
                style={styles.input}
              />
              <input
                placeholder="Last Name"
                value={form.lastName}
                onChange={(e) => setForm({ ...form, lastName: e.target.value })}
                style={styles.input}
              />
              <input
                placeholder="Username"
                value={form.username}
                onChange={(e) => setForm({ ...form, username: e.target.value })}
                required
                style={styles.input}
              />
              <input
                placeholder="Password (min 6 characters)"
                type="password"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                required
                style={styles.input}
              />
              <input
                placeholder="Phone Number"
                value={form.phoneNumber}
                onChange={(e) => setForm({ ...form, phoneNumber: e.target.value })}
                style={styles.input}
              />
            </div>
            <button type="submit" disabled={creating} style={styles.submitBtn}>
              {creating ? 'Creating...' : 'Create Rider Account'}
            </button>
          </form>
        )}

        {staff.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No delivery staff added yet.</p>
        ) : (
          <div style={styles.grid}>
            {staff.map((rider) => (
              <div key={rider.id} style={styles.card}>
                <div style={styles.cardHeader}>
                  <div>
                    <strong>{rider.first_name} {rider.last_name}</strong>
                    <p style={styles.username}>@{rider.username}</p>
                  </div>
                  <span
                    style={{
                      ...styles.badge,
                      backgroundColor: rider.delivery_approved ? '#4CAF5022' : '#E5393522',
                      color: rider.delivery_approved ? '#4CAF50' : '#E53935',
                    }}
                  >
                    {rider.delivery_approved ? 'Active' : 'Deactivated'}
                  </span>
                </div>
                {rider.phone_number && <p style={styles.phone}>📞 {rider.phone_number}</p>}
                <button
                  style={{
                    ...styles.toggleBtn,
                    color: rider.delivery_approved ? '#E53935' : '#4CAF50',
                    borderColor: rider.delivery_approved ? '#E53935' : '#4CAF50',
                  }}
                  disabled={toggling === rider.id}
                  onClick={() => handleToggle(rider.id)}
                >
                  {toggling === rider.id
                    ? 'Updating...'
                    : rider.delivery_approved
                      ? 'Deactivate'
                      : 'Reactivate'}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  page: { padding: '32px', maxWidth: '1000px' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' },
  addBtn: {
    padding: '10px 18px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '14px', fontWeight: 600,
  },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  form: {
    backgroundColor: '#fff', borderRadius: '12px', padding: '20px', marginBottom: '24px',
  },
  formGrid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginBottom: '16px',
  },
  input: {
    padding: '10px 12px', border: '1px solid #ddd', borderRadius: '8px', fontSize: '14px',
  },
  submitBtn: {
    padding: '10px 20px', backgroundColor: '#2B2B2B', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '14px', fontWeight: 600,
  },
  grid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: '16px',
  },
  card: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' },
  username: { fontSize: '12px', color: '#8E8E8E', margin: '2px 0 0' },
  badge: { padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 700, whiteSpace: 'nowrap' },
  phone: { fontSize: '13px', color: '#2B2B2B', margin: '4px 0 14px' },
  toggleBtn: {
    width: '100%', padding: '8px', backgroundColor: '#fff', border: '1px solid',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: 600,
  },
};