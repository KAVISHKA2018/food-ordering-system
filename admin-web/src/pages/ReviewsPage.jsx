import { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import reviewService from '../services/reviewService';

function StarRating({ rating }) {
  return (
    <span style={{ color: '#FFA000', fontSize: '15px', letterSpacing: '1px' }}>
      {'★'.repeat(rating)}
      <span style={{ color: '#E0E0E0' }}>{'★'.repeat(5 - rating)}</span>
    </span>
  );
}

export default function ReviewsPage() {
  const [tab, setTab] = useState('ORDER'); // ORDER or FOOD

  const [reviews, setReviews] = useState([]);
  const [foodReviews, setFoodReviews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('ALL');
  const [replyDrafts, setReplyDrafts] = useState({});
  const [submittingId, setSubmittingId] = useState(null);

  useEffect(() => {
    loadAll();
  }, []);

  const loadAll = async () => {
    setLoading(true);
    try {
      const [orderData, foodData] = await Promise.all([
        reviewService.getReviews(),
        reviewService.getFoodReviews(),
      ]);
      setReviews(orderData);
      setFoodReviews(foodData);
      setError('');
    } catch (err) {
      setError('Failed to load reviews.');
    } finally {
      setLoading(false);
    }
  };

  const handleReply = async (review) => {
    const text = (replyDrafts[review.id] ?? '').trim();
    if (!text) return;
    setSubmittingId(review.id);
    try {
      await reviewService.reply(review.id, text);
      loadAll();
    } catch (err) {
      setError('Failed to send reply.');
    } finally {
      setSubmittingId(null);
    }
  };

  const filteredOrderReviews = reviews.filter((r) => {
    if (filter === 'ALL') return true;
    if (filter === 'UNREPLIED') return !r.restaurant_reply;
    return r.rating === parseInt(filter, 10);
  });

  const filteredFoodReviews = foodReviews.filter((r) => {
    if (filter === 'ALL' || filter === 'UNREPLIED') return true;
    return r.rating === parseInt(filter, 10);
  });

  const currentList = tab === 'ORDER' ? filteredOrderReviews : filteredFoodReviews;
  const currentSource = tab === 'ORDER' ? reviews : foodReviews;

  const avgRating = currentSource.length
    ? (currentSource.reduce((sum, r) => sum + r.rating, 0) / currentSource.length).toFixed(1)
    : null;

  if (loading) return <Layout><div style={styles.page}>Loading...</div></Layout>;

  return (
    <Layout>
      <div style={styles.page}>
        <div style={styles.header}>
          <h1>Reviews & Ratings</h1>
          {avgRating && (
            <div style={styles.avgBox}>
              <span style={{ fontSize: '24px', fontWeight: 'bold' }}>{avgRating}</span>
              <StarRating rating={Math.round(avgRating)} />
              <span style={{ color: '#8E8E8E', fontSize: '13px' }}>({currentSource.length} reviews)</span>
            </div>
          )}
        </div>
        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.tabs}>
          <button
            style={{ ...styles.tabBtn, ...(tab === 'ORDER' ? styles.tabBtnActive : {}) }}
            onClick={() => setTab('ORDER')}
          >
            Order Reviews ({reviews.length})
          </button>
          <button
            style={{ ...styles.tabBtn, ...(tab === 'FOOD' ? styles.tabBtnActive : {}) }}
            onClick={() => setTab('FOOD')}
          >
            Food Reviews ({foodReviews.length})
          </button>
        </div>

        <div style={styles.filters}>
          {tab === 'ORDER'
            ? ['ALL', 'UNREPLIED', '5', '4', '3', '2', '1'].map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  style={{
                    ...styles.filterBtn,
                    backgroundColor: filter === f ? '#E8865A' : '#fff',
                    color: filter === f ? '#fff' : '#2B2B2B',
                  }}
                >
                  {f === 'ALL' ? 'All' : f === 'UNREPLIED' ? 'Needs Reply' : `${f}★`}
                </button>
              ))
            : ['ALL', '5', '4', '3', '2', '1'].map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  style={{
                    ...styles.filterBtn,
                    backgroundColor: filter === f ? '#E8865A' : '#fff',
                    color: filter === f ? '#fff' : '#2B2B2B',
                  }}
                >
                  {f === 'ALL' ? 'All' : `${f}★`}
                </button>
              ))}
        </div>

        {currentList.length === 0 ? (
          <p style={{ color: '#8E8E8E' }}>No reviews in this category.</p>
        ) : tab === 'ORDER' ? (
          <div style={styles.list}>
            {filteredOrderReviews.map((review) => (
              <div key={review.id} style={styles.card}>
                <div style={styles.cardHeader}>
                  <div>
                    <strong>{review.customer_username}</strong>
                    <div><StarRating rating={review.rating} /></div>
                  </div>
                  <span style={{ fontSize: '12px', color: '#8E8E8E' }}>
                    {new Date(review.created_at).toLocaleDateString()}
                  </span>
                </div>
                {review.comment && <p style={styles.comment}>{review.comment}</p>}

                {review.restaurant_reply ? (
                  <div style={styles.replyBox}>
                    <p style={styles.replyLabel}>Your reply</p>
                    <p style={{ margin: 0, fontSize: '13px' }}>{review.restaurant_reply}</p>
                  </div>
                ) : (
                  <div style={{ marginTop: '10px' }}>
                    <textarea
                      style={styles.replyInput}
                      placeholder="Write a reply..."
                      value={replyDrafts[review.id] ?? ''}
                      onChange={(e) =>
                        setReplyDrafts({ ...replyDrafts, [review.id]: e.target.value })
                      }
                    />
                    <button
                      style={styles.replyBtn}
                      disabled={submittingId === review.id}
                      onClick={() => handleReply(review)}
                    >
                      {submittingId === review.id ? 'Sending...' : 'Reply'}
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div style={styles.list}>
            {filteredFoodReviews.map((review) => (
              <div key={review.id} style={styles.card}>
                <div style={styles.cardHeader}>
                  <div>
                    <strong>{review.item_name}</strong>
                    <div style={{ fontSize: '12px', color: '#8E8E8E', marginTop: '2px' }}>
                      by {review.customer_username}
                    </div>
                    <div style={{ marginTop: '4px' }}><StarRating rating={review.rating} /></div>
                  </div>
                  <span style={{ fontSize: '12px', color: '#8E8E8E' }}>
                    {new Date(review.created_at).toLocaleDateString()}
                  </span>
                </div>
                {review.comment && <p style={styles.comment}>{review.comment}</p>}
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  page: { padding: '32px', maxWidth: '800px' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' },
  avgBox: { display: 'flex', alignItems: 'center', gap: '10px', backgroundColor: '#fff', padding: '10px 18px', borderRadius: '12px' },
  error: { backgroundColor: '#FFEBEE', color: '#C62828', padding: '10px', borderRadius: '8px', marginBottom: '16px' },
  tabs: { display: 'flex', gap: '8px', marginBottom: '16px', borderBottom: '1px solid #eee', paddingBottom: '12px' },
  tabBtn: {
    padding: '8px 16px', backgroundColor: '#fff', border: '1px solid #ddd', borderRadius: '8px',
    cursor: 'pointer', fontSize: '13px', fontWeight: 600, color: '#2B2B2B',
  },
  tabBtnActive: { backgroundColor: '#2B2B2B', color: '#fff', borderColor: '#2B2B2B' },
  filters: { display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '24px' },
  filterBtn: {
    padding: '8px 14px', border: '1px solid #ddd', borderRadius: '20px', cursor: 'pointer', fontSize: '13px',
  },
  list: { display: 'flex', flexDirection: 'column', gap: '14px' },
  card: { backgroundColor: '#fff', borderRadius: '12px', padding: '18px' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' },
  comment: { fontSize: '14px', color: '#2B2B2B', margin: '10px 0 0' },
  replyBox: { backgroundColor: '#FFF8F3', borderRadius: '8px', padding: '10px', marginTop: '12px' },
  replyLabel: { margin: '0 0 4px', fontSize: '11px', fontWeight: 700, color: '#E8865A' },
  replyInput: {
    width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #ddd',
    fontSize: '13px', boxSizing: 'border-box', marginBottom: '8px', minHeight: '60px',
  },
  replyBtn: {
    padding: '8px 16px', backgroundColor: '#E8865A', color: '#fff', border: 'none',
    borderRadius: '8px', cursor: 'pointer', fontSize: '13px',
  },
};