import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import restaurantService from '../services/restaurantService';
import { API_CONFIG } from '../config/apiConfig';

function imageUrl(path) {
  if (!path) return null;
  if (path.startsWith('http')) return path;
  const base = API_CONFIG.baseURL.replace('/api', '');
  return `${base}${path}`;
}

export default function MenuManagementPage() {
  const [restaurant, setRestaurant] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [newCategoryName, setNewCategoryName] = useState('');

  const [showItemForm, setShowItemForm] = useState(false);
  const [editingItem, setEditingItem] = useState(null);
  const [itemForm, setItemForm] = useState({
    name: '', description: '', price: '', category: '', is_available: true,
  });
  const [newCategoryInline, setNewCategoryInline] = useState('');
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);

  const [variantRows, setVariantRows] = useState([]);

  useEffect(() => {
    loadRestaurant();
  }, []);

  const loadRestaurant = async () => {
    setLoading(true);
    try {
      const data = await restaurantService.getMyRestaurant();
      setRestaurant(data);
    } catch (err) {
      setError('Failed to load restaurant data.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddCategory = async (e) => {
    e.preventDefault();
    if (!newCategoryName.trim()) return;
    try {
      await restaurantService.createCategory({
        restaurant: restaurant.id,
        name: newCategoryName.trim(),
        display_order: restaurant.categories?.length || 0,
      });
      setNewCategoryName('');
      loadRestaurant();
    } catch (err) {
      setError('Failed to add category.');
    }
  };

  const handleDeleteCategory = async (id) => {
    if (!confirm('Delete this category? Items inside will become uncategorized, not deleted.')) return;
    try {
      await restaurantService.deleteCategory(id);
      loadRestaurant();
    } catch (err) {
      setError('Failed to delete category.');
    }
  };

  const openNewItemForm = (categoryId = '') => {
    setEditingItem(null);
    setItemForm({ name: '', description: '', price: '', category: categoryId, is_available: true });
    setNewCategoryInline('');
    setImageFile(null);
    setImagePreview(null);
    setVariantRows([]);
    setShowItemForm(true);
  };

  const openEditItemForm = (item) => {
    setEditingItem(item);
    setItemForm({
      name: item.name,
      description: item.description || '',
      price: item.price,
      category: item.category || '',
      is_available: item.is_available,
    });
    setNewCategoryInline('');
    setImageFile(null);
    setImagePreview(imageUrl(item.image));
    setVariantRows(
      (item.variants || []).map((v) => ({
        id: v.id,
        name: v.name,
        price: v.price,
        isNew: false,
        isDeleted: false,
      }))
    );
    setShowItemForm(true);
  };

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setImageFile(file);
      setImagePreview(URL.createObjectURL(file));
    }
  };

  const addVariantRow = () => {
    setVariantRows([
      ...variantRows,
      { id: `temp-${Date.now()}`, name: '', price: '', isNew: true, isDeleted: false },
    ]);
  };

  const updateVariantRow = (id, field, value) => {
    setVariantRows(variantRows.map((v) => (v.id === id ? { ...v, [field]: value } : v)));
  };

  const removeVariantRow = (id) => {
    setVariantRows(
      variantRows
        .map((v) => (v.id === id ? { ...v, isDeleted: true } : v))
        .filter((v) => !(v.isNew && v.isDeleted)) // if it was never saved, just drop it entirely
    );
  };
  
  const handleSaveItem = async (e) => {
    e.preventDefault();

    let categoryId = itemForm.category;

    try {
      if (categoryId === '__new__') {
        if (!newCategoryInline.trim()) {
          setError('Please enter a name for the new category.');
          return;
        }
        const created = await restaurantService.createCategory({
          restaurant: restaurant.id,
          name: newCategoryInline.trim(),
          display_order: restaurant.categories?.length || 0,
        });
        categoryId = created.id;
      }

      const formData = new FormData();
      formData.append('restaurant', restaurant.id);
      formData.append('name', itemForm.name);
      formData.append('description', itemForm.description);
      formData.append('price', parseFloat(itemForm.price));
      if (categoryId) formData.append('category', categoryId);
      formData.append('is_available', itemForm.is_available ? 'true' : 'false');
      formData.append('stock_quantity', editingItem ? editingItem.stock_quantity : 9999);
      if (imageFile) {
        formData.append('image', imageFile);
      }

      let savedItem;
      if (editingItem) {
        savedItem = await restaurantService.updateMenuItem(editingItem.id, formData);
      } else {
        savedItem = await restaurantService.createMenuItem(formData);
      }

      // Sync variants: create new ones, update changed ones, delete removed ones
      for (const v of variantRows) {
        if (v.isDeleted && !v.isNew) {
          await restaurantService.deleteVariant(v.id);
        } else if (v.isNew && !v.isDeleted && v.name.trim() && v.price !== '') {
          await restaurantService.createVariant({
            menu_item: savedItem.id,
            name: v.name.trim(),
            price: parseFloat(v.price),
          });
        } else if (!v.isNew && !v.isDeleted && v.name.trim() && v.price !== '') {
          await restaurantService.updateVariant(v.id, {
            name: v.name.trim(),
            price: parseFloat(v.price),
          });
        }
      }

      setShowItemForm(false);
      setNewCategoryInline('');
      setImageFile(null);
      setImagePreview(null);
      setVariantRows([]);
      loadRestaurant();
    } catch (err) {
      console.error('Save item error:', err.response?.data || err.message);
      setError(
        err.response?.data
          ? JSON.stringify(err.response.data)
          : 'Failed to save menu item.'
      );
    }
  };

  const handleDeleteItem = async (id) => {
    if (!confirm('Delete this menu item?')) return;
    try {
      await restaurantService.deleteMenuItem(id);
      loadRestaurant();
    } catch (err) {
      setError('Failed to delete item.');
    }
  };

  const toggleAvailability = async (item) => {
    try {
      const formData = new FormData();
      formData.append('is_available', (!item.is_available) ? 'true' : 'false');
      await restaurantService.updateMenuItem(item.id, formData);
      loadRestaurant();

    } catch (err) {
      console.error('Toggle availability error:', err.response?.data || err.message);
      setError(
        err.response?.data
          ? JSON.stringify(err.response.data)
          : 'Failed to update availability.'
      );
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

  return (
    <Layout>
      <div style={styles.page}>
        <h1>{restaurant.name} — Menu Management</h1>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.addCategoryBox}>
          <form onSubmit={handleAddCategory} style={{ display: 'flex', gap: '8px' }}>
            <input
              style={styles.input}
              placeholder="New category name (e.g. Appetizers)"
              value={newCategoryName}
              onChange={(e) => setNewCategoryName(e.target.value)}
            />
            <button type="submit" style={styles.primaryBtn}>Add Category</button>
          </form>
        </div>

        {(!restaurant.categories || restaurant.categories.length === 0) && (
          <p style={{ color: '#8E8E8E' }}>No categories yet. Add one above to start building your menu.</p>
        )}

        {restaurant.categories?.map((category) => (
          <div key={category.id} style={styles.categoryCard}>
            <div style={styles.categoryHeader}>
              <h3 style={{ margin: 0 }}>{category.name}</h3>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button style={styles.smallBtn} onClick={() => openNewItemForm(category.id)}>
                  + Add Item
                </button>
                <button style={styles.smallDangerBtn} onClick={() => handleDeleteCategory(category.id)}>
                  Delete Category
                </button>
              </div>
            </div>

            {category.menu_items?.length === 0 ? (
              <p style={{ color: '#8E8E8E', fontSize: '13px' }}>No items in this category yet.</p>
            ) : (
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>Image</th>
                    <th style={styles.th}>Name</th>
                    <th style={styles.th}>Price</th>
                    <th style={styles.th}>Available</th>
                    <th style={styles.th}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {category.menu_items?.map((item) => (
                    <tr key={item.id}>
                      <td style={styles.td}>
                        {item.image ? (
                          <img src={imageUrl(item.image)} alt={item.name} style={styles.thumb} />
                        ) : (
                          <div style={styles.thumbPlaceholder}>—</div>
                        )}
                      </td>
                      <td style={styles.td}>{item.name}</td>
                      <td style={styles.td}>
                        {item.variants?.length > 0 ? (
                          <span title={item.variants.map((v) => `${v.name}: Rs.${v.price}`).join(', ')}>
                            {item.variants.length} size{item.variants.length > 1 ? 's' : ''}
                          </span>
                        ) : (
                          `Rs. ${parseFloat(item.price).toFixed(0)}`
                        )}
                        {item.average_rating && (
                          <div style={styles.ratingBadge}>
                            ★ {item.average_rating} ({item.review_count})
                          </div>
                        )}
                      </td>
                      <td style={styles.td}>
                        <label style={styles.toggle}>
                          <input
                            type="checkbox"
                            checked={item.is_available}
                            onChange={() => toggleAvailability(item)}
                          />
                          {item.is_available ? 'Yes' : 'No'}
                        </label>
                      </td>
                      <td style={styles.td}>
                        <button style={styles.linkBtn} onClick={() => openEditItemForm(item)}>Edit</button>
                        <button style={styles.linkBtnDanger} onClick={() => handleDeleteItem(item.id)}>Delete</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        ))}

        {restaurant.uncategorized_items?.length > 0 && (
          <div style={styles.categoryCard}>
            <div style={styles.categoryHeader}>
              <h3 style={{ margin: 0 }}>Uncategorized</h3>
              <button style={styles.smallBtn} onClick={() => openNewItemForm('')}>
                + Add Item
              </button>
            </div>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>Image</th>
                  <th style={styles.th}>Name</th>
                  <th style={styles.th}>Price</th>
                  <th style={styles.th}>Available</th>
                  <th style={styles.th}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {restaurant.uncategorized_items.map((item) => (
                  <tr key={item.id}>
                    <td style={styles.td}>
                      {item.image ? (
                        <img src={imageUrl(item.image)} alt={item.name} style={styles.thumb} />
                      ) : (
                        <div style={styles.thumbPlaceholder}>—</div>
                      )}
                    </td>
                    <td style={styles.td}>{item.name}</td>
                    <td style={styles.td}>Rs. {parseFloat(item.price).toFixed(0)}</td>
                    <td style={styles.td}>
                      <label style={styles.toggle}>
                        <input
                          type="checkbox"
                          checked={item.is_available}
                          onChange={() => toggleAvailability(item)}
                        />
                        {item.is_available ? 'Yes' : 'No'}
                      </label>
                    </td>
                    <td style={styles.td}>
                      <button style={styles.linkBtn} onClick={() => openEditItemForm(item)}>Edit</button>
                      <button style={styles.linkBtnDanger} onClick={() => handleDeleteItem(item.id)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {showItemForm && (
          <div style={styles.modalOverlay}>
            <div style={styles.modal}>
              <h3>{editingItem ? 'Edit Item' : 'Add Menu Item'}</h3>
              <form onSubmit={handleSaveItem}>
                <label style={styles.label}>Item Image</label>
                {imagePreview && (
                  <img src={imagePreview} alt="preview" style={styles.previewImg} />
                )}
                <input
                  style={styles.input}
                  type="file"
                  accept="image/*"
                  onChange={handleImageChange}
                />

                <label style={styles.label}>Name</label>
                <input
                  style={styles.input}
                  value={itemForm.name}
                  onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })}
                  required
                />
                <label style={styles.label}>Description</label>
                <textarea
                  style={{ ...styles.input, height: '60px' }}
                  value={itemForm.description}
                  onChange={(e) => setItemForm({ ...itemForm, description: e.target.value })}
                />
                <label style={styles.label}>Category</label>
                <select
                  style={styles.input}
                  value={itemForm.category}
                  onChange={(e) => {
                    setItemForm({ ...itemForm, category: e.target.value });
                    if (e.target.value !== '__new__') setNewCategoryInline('');
                  }}
                >
                  <option value="">Uncategorized</option>
                  {restaurant.categories?.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                  <option value="__new__">＋ Create New Category</option>
                </select>

                {itemForm.category === '__new__' && (
                  <input
                    style={styles.input}
                    placeholder="New category name"
                    value={newCategoryInline}
                    onChange={(e) => setNewCategoryInline(e.target.value)}
                    autoFocus
                  />
                )}

                <label style={styles.label}>
                  Price (Rs.)
                  {variantRows.filter((v) => !v.isDeleted).length > 0 && (
                    <span style={styles.priceDisabledNote}> — not used, sizes below set the price</span>
                  )}
                </label>
                <input
                  style={{
                    ...styles.input,
                    ...(variantRows.filter((v) => !v.isDeleted).length > 0 ? styles.inputDisabled : {}),
                  }}
                  type="number"
                  step="0.01"
                  value={itemForm.price}
                  onChange={(e) => setItemForm({ ...itemForm, price: e.target.value })}
                  disabled={variantRows.filter((v) => !v.isDeleted).length > 0}
                  required={variantRows.filter((v) => !v.isDeleted).length === 0}
                />

                <div style={styles.variantsSection}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <label style={styles.label}>Sizes / Variants (optional)</label>
                    <button type="button" style={styles.smallAddBtn} onClick={addVariantRow}>
                      + Add Size
                    </button>
                  </div>
                  <p style={styles.variantHint}>
                    e.g. Small / Medium / Large, or Half / Full. If you add sizes, customers
                    will pick one and its price replaces the base price above.
                  </p>
                  {variantRows.filter((v) => !v.isDeleted).map((v) => (
                    <div key={v.id} style={styles.variantRow}>
                      <input
                        style={{ ...styles.input, marginBottom: 0, flex: 2 }}
                        placeholder="Size name (e.g. Large)"
                        value={v.name}
                        onChange={(e) => updateVariantRow(v.id, 'name', e.target.value)}
                      />
                      <input
                        style={{ ...styles.input, marginBottom: 0, flex: 1 }}
                        type="number"
                        step="0.01"
                        placeholder="Price"
                        value={v.price}
                        onChange={(e) => updateVariantRow(v.id, 'price', e.target.value)}
                      />
                      <button
                        type="button"
                        style={styles.variantRemoveBtn}
                        onClick={() => removeVariantRow(v.id)}
                      >
                        ✕
                      </button>
                    </div>
                  ))}
                </div>
                <label style={{ ...styles.label, display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    type="checkbox"
                    checked={itemForm.is_available}
                    onChange={(e) => setItemForm({ ...itemForm, is_available: e.target.checked })}
                  />
                  Available for ordering
                </label>

                <div style={{ display: 'flex', gap: '8px', marginTop: '16px' }}>
                  <button type="submit" style={styles.primaryBtn}>Save</button>
                  <button
                    type="button"
                    style={styles.secondaryBtn}
                    onClick={() => setShowItemForm(false)}
                  >
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
  page: { padding: '32px', maxWidth: '900px' },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  addCategoryBox: { marginBottom: '24px', backgroundColor: '#fff', padding: '16px', borderRadius: '12px' },
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
  smallBtn: {
    padding: '6px 12px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '6px', cursor: 'pointer', fontSize: '12px',
  },
  smallDangerBtn: {
    padding: '6px 12px', backgroundColor: '#fff', color: '#E53935', border: '1px solid #E53935',
    borderRadius: '6px', cursor: 'pointer', fontSize: '12px',
  },
  categoryCard: { backgroundColor: '#fff', borderRadius: '12px', padding: '20px', marginBottom: '16px' },
  categoryHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: '13px' },
  th: { textAlign: 'left', padding: '8px', borderBottom: '2px solid #eee', color: '#8E8E8E' },
  td: { padding: '8px', borderBottom: '1px solid #f5f5f5' },
  thumb: { width: '44px', height: '44px', objectFit: 'cover', borderRadius: '8px' },
  thumbPlaceholder: {
    width: '44px', height: '44px', borderRadius: '8px', backgroundColor: '#f0f0f0',
    display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#bbb', fontSize: '12px',
  },
  previewImg: { width: '100%', maxHeight: '160px', objectFit: 'cover', borderRadius: '8px', marginBottom: '10px' },
  toggle: { display: 'flex', alignItems: 'center', gap: '6px' },
  linkBtn: { background: 'none', border: 'none', color: '#E8865A', cursor: 'pointer', marginRight: '10px', fontSize: '13px' },
  linkBtnDanger: { background: 'none', border: 'none', color: '#E53935', cursor: 'pointer', fontSize: '13px' },
  modalOverlay: {
    position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.4)', display: 'flex', justifyContent: 'center', alignItems: 'center',
  },
  modal: {
    backgroundColor: '#fff', padding: '24px', borderRadius: '12px', width: '400px', maxHeight: '90vh', overflowY: 'auto',
  },

  variantsSection: { marginTop: '8px', marginBottom: '10px' },
  variantHint: { fontSize: '12px', color: '#8E8E8E', margin: '4px 0 10px' },
  variantRow: { display: 'flex', gap: '8px', alignItems: 'center', marginBottom: '8px' },
  variantRemoveBtn: {
    background: '#fff', border: '1px solid #E53935', color: '#E53935',
    borderRadius: '6px', width: '32px', height: '38px', cursor: 'pointer', fontSize: '14px',
  },
  smallAddBtn: {
    padding: '4px 10px', backgroundColor: '#fff', color: '#E8865A', border: '1px solid #E8865A',
    borderRadius: '6px', cursor: 'pointer', fontSize: '12px',
  },
  priceDisabledNote: { color: '#8E8E8E', fontWeight: 400, fontSize: '11px' },
  inputDisabled: { backgroundColor: '#f5f5f5', color: '#aaa', cursor: 'not-allowed' },

  ratingBadge: { fontSize: '11px', color: '#FFA000', marginTop: '2px', fontWeight: 600 },
};