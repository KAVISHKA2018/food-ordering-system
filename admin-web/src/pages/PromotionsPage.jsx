import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import restaurantService from '../services/restaurantService';
import promotionService from '../services/promotionService';
import { imageUrl } from '../config/apiConfig';

function todayStr() {
  return new Date().toISOString().split('T')[0];
}

function isCurrentlyLive(promo) {
  const today = todayStr();
  return promo.is_active && promo.start_date <= today && promo.end_date >= today;
}

export default function PromotionsPage() {
  const [restaurant, setRestaurant] = useState(null);
  const [promotions, setPromotions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [showForm, setShowForm] = useState(false);
  const [editingPromo, setEditingPromo] = useState(null);
  const [form, setForm] = useState(emptyForm());

  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);

  function emptyForm() {
    return {
      title: '', description: '', code: '',
      discount_type: 'PERCENTAGE', discount_value: '', min_order_amount: '0',
      start_date: todayStr(), end_date: todayStr(), max_uses: '', is_active: true,
    };
  }

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const [restaurantData, promoData] = await Promise.all([
        restaurantService.getMyRestaurant(),
        promotionService.getPromotions(),
      ]);
      setRestaurant(restaurantData);
      setPromotions(promoData);
    } catch (err) {
      setError('Failed to load promotions.');
    } finally {
      setLoading(false);
    }
  };

  const openNewForm = () => {
    setEditingPromo(null);
    setForm(emptyForm());
    setImageFile(null);
    setImagePreview(null);
    setShowForm(true);
  };

  const openEditForm = (promo) => {
    setEditingPromo(promo);
    setForm({
      title: promo.title,
      description: promo.description || '',
      code: promo.code || '',
      discount_type: promo.discount_type,
      discount_value: promo.discount_value,
      min_order_amount: promo.min_order_amount,
      start_date: promo.start_date,
      end_date: promo.end_date,
      max_uses: promo.max_uses ?? '',
      is_active: promo.is_active,
    });
    setImageFile(null);
    setImagePreview(imageUrl(promo.image));
    setShowForm(true);
  };

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setImageFile(file);
      setImagePreview(URL.createObjectURL(file));
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!restaurant) return;

    const formData = new FormData();
    formData.append('restaurant', restaurant.id);
    formData.append('title', form.title);
    formData.append('description', form.description);
    formData.append('code', form.code.trim());
    formData.append('discount_type', form.discount_type);
    formData.append('discount_value', parseFloat(form.discount_value) || 0);
    formData.append('min_order_amount', parseFloat(form.min_order_amount) || 0);
    formData.append('start_date', form.start_date);
    formData.append('end_date', form.end_date);
    if (form.max_uses !== '') formData.append('max_uses', parseInt(form.max_uses, 10));
    formData.append('is_active', form.is_active ? 'true' : 'false');
    if (imageFile) formData.append('image', imageFile);

    try {
      if (editingPromo) {
        await promotionService.updatePromotion(editingPromo.id, formData);
      } else {
        await promotionService.createPromotion(formData);
      }
      setShowForm(false);
      setImageFile(null);
      setImagePreview(null);
      loadData();
    } catch (err) {
      setError(err.response?.data ? JSON.stringify(err.response.data) : 'Failed to save promotion.');
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this promotion?')) return;
    try {
      await promotionService.deletePromotion(id);
      loadData();
    } catch (err) {
      setError('Failed to delete promotion.');
    }
  };

  const handleToggleActive = async (promo) => {
    try {
      await promotionService.updatePromotion(promo.id, { is_active: !promo.is_active });
      loadData();
    } catch (err) {
      setError('Failed to update promotion.');
    }
  };

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  return (
    <Layout>
      <div style={styles.page}>
        <div style={styles.header}>
          <h1>Promotions & Offers</h1>
          <button style={styles.primaryBtn} onClick={openNewForm}>+ New Promotion</button>
        </div>
        {error && <div style={styles.error}>{error}</div>}

        {promotions.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No promotions yet. Create one to attract customers.</p>
        ) : (
          <div style={styles.grid}>
            {promotions.map((promo) => {
              const live = isCurrentlyLive(promo);
              return (
                <div key={promo.id} style={styles.card}>
                   {promo.image && (
                    <img src={imageUrl(promo.image)} alt={promo.title} style={styles.cardImage} />
                  )} 
                  <div style={styles.cardHeader}>
                    <strong>{promo.title}</strong>
                    <span
                      style={{
                        ...styles.badge,
                        backgroundColor: live ? '#E8F5E9' : '#F5F5F5',
                        color: live ? '#4CAF50' : '#9E9E9E',
                      }}
                    >
                      {live ? 'Live' : promo.is_active ? 'Scheduled/Expired' : 'Disabled'}
                    </span>
                  </div>
                  {promo.description && (
                    <p style={{ fontSize: '13px', color: '#8E8E8E', margin: '6px 0' }}>{promo.description}</p>
                  )}
                  <div style={styles.detailRow}>
                    <span>Discount</span>
                    <strong>
                      {promo.discount_type === 'PERCENTAGE'
                        ? `${promo.discount_value}%`
                        : `Rs. ${promo.discount_value}`}
                    </strong>
                  </div>
                  <div style={styles.detailRow}>
                    <span>Code</span>
                    <strong>{promo.code || 'Auto-applied'}</strong>
                  </div>
                  <div style={styles.detailRow}>
                    <span>Min Order</span>
                    <strong>Rs. {promo.min_order_amount}</strong>
                  </div>
                  <div style={styles.detailRow}>
                    <span>Valid</span>
                    <strong>{promo.start_date} → {promo.end_date}</strong>
                  </div>
                  <div style={styles.detailRow}>
                    <span>Uses</span>
                    <strong>{promo.used_count}{promo.max_uses ? ` / ${promo.max_uses}` : ' (unlimited)'}</strong>
                  </div>

                  <div style={styles.actions}>
                    <button style={styles.linkBtn} onClick={() => openEditForm(promo)}>Edit</button>
                    <button style={styles.linkBtn} onClick={() => handleToggleActive(promo)}>
                      {promo.is_active ? 'Disable' : 'Enable'}
                    </button>
                    <button style={styles.linkBtnDanger} onClick={() => handleDelete(promo.id)}>Delete</button>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {showForm && (
          <div style={styles.modalOverlay}>
            <div style={styles.modal}>
              <h3>{editingPromo ? 'Edit Promotion' : 'New Promotion'}</h3>
              <form onSubmit={handleSave}>
                <label style={styles.label}>Promo Image</label>
                {imagePreview && (
                  <img src={imagePreview} alt="preview" style={styles.previewImg} />
                )}
                <input
                  style={styles.input}
                  type="file"
                  accept="image/*"
                  onChange={handleImageChange}
                />

                <label style={styles.label}>Title</label>
                <input
                  style={styles.input}
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  required
                />
                <label style={styles.label}>Description</label>
                <textarea
                  style={{ ...styles.input, height: '60px' }}
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                />
                <label style={styles.label}>Promo Code (optional)</label>
                <input
                  style={styles.input}
                  placeholder="Leave blank to auto-apply to every order"
                  value={form.code}
                  onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
                />

                <div style={{ display: 'flex', gap: '8px' }}>
                  <div style={{ flex: 1 }}>
                    <label style={styles.label}>Discount Type</label>
                    <select
                      style={styles.input}
                      value={form.discount_type}
                      onChange={(e) => setForm({ ...form, discount_type: e.target.value })}
                    >
                      <option value="PERCENTAGE">Percentage (%)</option>
                      <option value="FIXED">Fixed Amount (Rs.)</option>
                    </select>
                  </div>
                  <div style={{ flex: 1 }}>
                    <label style={styles.label}>
                      {form.discount_type === 'PERCENTAGE' ? 'Percent Off' : 'Amount Off (Rs.)'}
                    </label>
                    <input
                      style={styles.input}
                      type="number"
                      step="0.01"
                      value={form.discount_value}
                      onChange={(e) => setForm({ ...form, discount_value: e.target.value })}
                      required
                    />
                  </div>
                </div>

                <label style={styles.label}>Minimum Order Amount (Rs.)</label>
                <input
                  style={styles.input}
                  type="number"
                  step="0.01"
                  value={form.min_order_amount}
                  onChange={(e) => setForm({ ...form, min_order_amount: e.target.value })}
                />

                <div style={{ display: 'flex', gap: '8px' }}>
                  <div style={{ flex: 1 }}>
                    <label style={styles.label}>Start Date</label>
                    <input
                      style={styles.input}
                      type="date"
                      value={form.start_date}
                      onChange={(e) => setForm({ ...form, start_date: e.target.value })}
                      required
                    />
                  </div>
                  <div style={{ flex: 1 }}>
                    <label style={styles.label}>End Date</label>
                    <input
                      style={styles.input}
                      type="date"
                      value={form.end_date}
                      onChange={(e) => setForm({ ...form, end_date: e.target.value })}
                      required
                    />
                  </div>
                </div>

                <label style={styles.label}>Max Uses (optional)</label>
                <input
                  style={styles.input}
                  type="number"
                  placeholder="Leave blank for unlimited"
                  value={form.max_uses}
                  onChange={(e) => setForm({ ...form, max_uses: e.target.value })}
                />

                <label style={{ ...styles.label, display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                  />
                  Active
                </label>

                <div style={{ display: 'flex', gap: '8px', marginTop: '16px' }}>
                  <button type="submit" style={styles.primaryBtn}>Save</button>
                  <button type="button" style={styles.secondaryBtn} onClick={() => setShowForm(false)}>
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  page: { padding: '32px', maxWidth: '1000px' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '16px' },
  card: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' },
  badge: { padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 700, whiteSpace: 'nowrap' },
  detailRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginTop: '6px' },
  actions: { display: 'flex', gap: '10px', marginTop: '14px', borderTop: '1px solid #f0f0f0', paddingTop: '10px' },
  linkBtn: { background: 'none', border: 'none', color: '#E8865A', cursor: 'pointer', fontSize: '13px' },
  linkBtnDanger: { background: 'none', border: 'none', color: '#E53935', cursor: 'pointer', fontSize: '13px' },
  previewImg: { width: '100%', maxHeight: '140px', objectFit: 'cover', borderRadius: '8px', marginBottom: '10px' },
  cardImage: { width: '100%', height: '120px', objectFit: 'cover', borderRadius: '8px', marginBottom: '10px' },
  input: {
    padding: '10px', borderRadius: '8px', border: '1px solid #ddd', fontSize: '14px',
    width: '100%', boxSizing: 'border-box', marginBottom: '10px',
  },
  label: { fontSize: '13px', fontWeight: 600, color: '#2B2B2B', display: 'block', marginBottom: '4px' },
  primaryBtn: {
    padding: '10px 16px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '14px', whiteSpace: 'nowrap',
  },
  secondaryBtn: {
    padding: '10px 16px', backgroundColor: '#eee', color: '#2B2B2B', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '14px',
  },
  modalOverlay: {
    position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.4)', display: 'flex', justifyContent: 'center', alignItems: 'center',
    zIndex: 100,
  },
  modal: {
    backgroundColor: '#fff', padding: '24px', borderRadius: '12px', width: '420px',
    maxHeight: '90vh', overflowY: 'auto',
  },
};