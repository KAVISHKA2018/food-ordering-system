import math
import numpy as np
import pandas as pd
from datetime import date
from django.db.models import Count, Avg
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from restaurants.models import MenuItem
from orders.models import OrderItem, Order
from reviews.models import FoodReview

# Hybrid score weights — must sum to 1.0
W_CONTENT = 0.35
W_RATING = 0.15
W_COPURCHASE = 0.20
W_RESTAURANT = 0.10
W_POPULARITY = 0.20

RECENCY_HALF_LIFE_DAYS = 30  # an order from 30 days ago counts half as much as one from today
MMR_LAMBDA = 0.75  # 1.0 = pure relevance, 0.0 = pure diversity


def _build_item_features(restaurant_id=None):
    """One row per available menu item, with name kept separately (for
    explanation text) and a combined text field (name + category +
    description) that TF-IDF will analyze."""
    queryset = MenuItem.objects.filter(is_available=True).select_related('category', 'restaurant')
    if restaurant_id:
        queryset = queryset.filter(restaurant_id=restaurant_id)

    rows = []
    for item in queryset:
        category_name = item.category.name if item.category else ''
        text = f"{item.name} {category_name} {item.description or ''}"
        rows.append({
            'id': item.id,
            'text': text,
            'name': item.name,
            'restaurant_id': item.restaurant_id,
        })

    return pd.DataFrame(rows)


def _content_similarity_matrix(df):
    """Converts item text into TF-IDF vectors, then computes how similar
    every item is to every other item (cosine similarity, 0 to 1)."""
    if df.empty:
        return None, []
    vectorizer = TfidfVectorizer(stop_words='english')
    tfidf_matrix = vectorizer.fit_transform(df['text'])
    matrix = cosine_similarity(tfidf_matrix)
    return matrix, df['id'].tolist()


def _customer_item_weights(user, restaurant_id=None):
    """How much influence each item this customer has ordered should have,
    combining order FREQUENCY with RECENCY (exponential decay)."""
    queryset = OrderItem.objects.filter(
        order__customer=user, order__status=Order.Status.COMPLETED
    ).select_related('order')
    if restaurant_id:
        queryset = queryset.filter(order__restaurant_id=restaurant_id)

    today = date.today()
    weights = {}
    for order_item in queryset:
        if not order_item.menu_item_id:
            continue
        days_ago = (today - order_item.order.created_at.date()).days
        recency_factor = math.pow(0.5, days_ago / RECENCY_HALF_LIFE_DAYS)
        weights[order_item.menu_item_id] = weights.get(order_item.menu_item_id, 0) + recency_factor

    return weights


def _item_rating_scores(item_ids):
    """Average food rating per item, normalized to 0-1. Unreviewed items
    get a neutral 0.5 rather than 0."""
    ratings = (
        FoodReview.objects.filter(menu_item_id__in=item_ids)
        .values('menu_item_id')
        .annotate(avg_rating=Avg('rating'))
    )
    rating_map = {row['menu_item_id']: row['avg_rating'] / 5.0 for row in ratings}
    return {item_id: rating_map.get(item_id, 0.5) for item_id in item_ids}


def _copurchase_scores(seed_item_ids, candidate_item_ids):
    """For each candidate, how often has it appeared in the SAME order as
    one of the customer's favorite items, across ALL customers?"""
    if not seed_item_ids:
        return {item_id: 0.0 for item_id in candidate_item_ids}

    relevant_order_ids = (
        OrderItem.objects.filter(menu_item_id__in=seed_item_ids)
        .values_list('order_id', flat=True)
        .distinct()
    )

    counts = (
        OrderItem.objects.filter(order_id__in=relevant_order_ids, menu_item_id__in=candidate_item_ids)
        .values('menu_item_id')
        .annotate(co_count=Count('id'))
    )
    raw = {row['menu_item_id']: row['co_count'] for row in counts}
    if not raw:
        return {item_id: 0.0 for item_id in candidate_item_ids}

    max_count = max(raw.values())
    return {item_id: raw.get(item_id, 0) / max_count for item_id in candidate_item_ids}


def _popularity_scores(candidate_ids):
    """How often each candidate has been ordered, across ALL customers —
    normalized 0-1 against the most popular candidate. This is what lets
    a genuinely best-selling dish get a boost even in a personalized list,
    not just as the cold-start fallback."""
    counts = (
        OrderItem.objects.filter(
            menu_item_id__in=candidate_ids, order__status=Order.Status.COMPLETED
        )
        .values('menu_item_id')
        .annotate(order_count=Count('id'))
    )
    raw = {row['menu_item_id']: row['order_count'] for row in counts}
    if not raw:
        return {item_id: 0.0 for item_id in candidate_ids}

    max_count = max(raw.values())
    return {item_id: raw.get(item_id, 0) / max_count for item_id in candidate_ids}


def _customer_known_restaurants(user):
    """Restaurant IDs this customer has completed at least one order from —
    used for the 'familiarity' boost."""
    return set(
        Order.objects.filter(customer=user, status=Order.Status.COMPLETED)
        .values_list('restaurant_id', flat=True)
        .distinct()
    )


def _mmr_diversify(candidate_ids, relevance, similarity_matrix, id_to_index, limit, lambda_param=MMR_LAMBDA):
    """Maximal Marginal Relevance re-ranking: repeatedly picks the highest
    remaining (relevance - similarity_to_already_picked) item. This is what
    stops near-duplicate items (e.g. three very similarly-worded dishes)
    from all clustering at the top of the list."""
    selected = []
    remaining = list(candidate_ids)

    while remaining and len(selected) < limit:
        best_id, best_score = None, -1e9
        for cid in remaining:
            rel = relevance.get(cid, 0)
            if selected:
                sim_to_selected = max(
                    similarity_matrix[id_to_index[cid]][id_to_index[sid]] for sid in selected
                )
            else:
                sim_to_selected = 0
            mmr_score = lambda_param * rel - (1 - lambda_param) * sim_to_selected
            if mmr_score > best_score:
                best_score, best_id = mmr_score, cid
        selected.append(best_id)
        remaining.remove(best_id)

    return selected


def recommend_for_user(user, restaurant_id=None, limit=10):
    """Hybrid, diversified, explainable recommendation. Returns a list of
    dicts: [{'item_id': int, 'reason': str}, ...], or None if there's no
    order history to learn from (caller falls back to popularity)."""
    df = _build_item_features(restaurant_id)
    if df.empty:
        return []

    matrix, item_ids = _content_similarity_matrix(df)
    id_to_index = {item_id: idx for idx, item_id in enumerate(item_ids)}
    id_to_name = dict(zip(df['id'], df['name']))
    id_to_restaurant = dict(zip(df['id'], df['restaurant_id']))

    customer_weights = _customer_item_weights(user, restaurant_id)
    customer_weights = {k: v for k, v in customer_weights.items() if k in item_ids}
    if not customer_weights:
        return None

    ordered_indices = [id_to_index[item_id] for item_id in customer_weights.keys()]
    raw_weights = np.array([customer_weights[item_ids[idx]] for idx in ordered_indices], dtype=float)
    norm_weights = raw_weights / raw_weights.sum()

    content_scores = np.average(matrix[ordered_indices], axis=0, weights=norm_weights)

    already_ordered = set(customer_weights.keys())
    candidate_ids = [item_ids[idx] for idx in range(len(item_ids)) if item_ids[idx] not in already_ordered]

    rating_scores = _item_rating_scores(candidate_ids)
    copurchase_scores = _copurchase_scores(list(already_ordered), candidate_ids)
    popularity_scores = _popularity_scores(candidate_ids)
    known_restaurants = _customer_known_restaurants(user)

    relevance = {}
    reasons = {}

    for item_id in candidate_ids:
        idx = id_to_index[item_id]
        content = content_scores[idx]
        rating = rating_scores.get(item_id, 0.5)
        copurchase = copurchase_scores.get(item_id, 0.0)
        popularity = popularity_scores.get(item_id, 0.0)
        restaurant_bonus = 1.0 if id_to_restaurant.get(item_id) in known_restaurants else 0.0

        score = (
            W_CONTENT * content
            + W_RATING * rating
            + W_COPURCHASE * copurchase
            + W_RESTAURANT * restaurant_bonus
            + W_POPULARITY * popularity
        )
        relevance[item_id] = score

        # Which of the customer's own ordered items drove the content score highest?
        best_seed_id, best_seed_sim = None, -1
        for seed_id in already_ordered:
            sim = matrix[id_to_index[seed_id]][idx]
            if sim > best_seed_sim:
                best_seed_sim, best_seed_id = sim, seed_id

        # Decide which signal best explains this recommendation, in order
        # of how "specific and convincing" the reason is.
        content_contribution = W_CONTENT * content
        copurchase_contribution = W_COPURCHASE * copurchase
        restaurant_contribution = W_RESTAURANT * restaurant_bonus
        popularity_contribution = W_POPULARITY * popularity

        if copurchase_contribution > content_contribution and copurchase > 0.3:
            reasons[item_id] = "Frequently ordered alongside your favorites"
        elif content_contribution >= max(copurchase_contribution, restaurant_contribution, popularity_contribution) and best_seed_id:
            reasons[item_id] = f"Because you liked {id_to_name.get(best_seed_id, 'a similar dish')}"
        elif popularity_contribution >= restaurant_contribution and popularity > 0.5:
            reasons[item_id] = "Best-selling item"
        elif restaurant_contribution > 0:
            reasons[item_id] = "From a restaurant you've ordered from before"
        else:
            reasons[item_id] = "Popular pick"

    diversified_ids = _mmr_diversify(candidate_ids, relevance, matrix, id_to_index, limit)

    return [{'item_id': item_id, 'reason': reasons.get(item_id, 'Recommended for you')} for item_id in diversified_ids]


def get_popular_items(restaurant_id=None, limit=10):
    """Fallback for new customers with no order history."""
    queryset = OrderItem.objects.filter(order__status=Order.Status.COMPLETED)
    if restaurant_id:
        queryset = queryset.filter(order__restaurant_id=restaurant_id)

    popular = (
        queryset.values('menu_item_id')
        .annotate(order_count=Count('id'))
        .order_by('-order_count')[:limit]
    )
    return [
        {'item_id': row['menu_item_id'], 'reason': 'Popular choice'}
        for row in popular if row['menu_item_id']
    ]


def get_reorder_items(user, limit=10):
    """The customer's own most-repeated items — simple 'order it again'."""
    queryset = OrderItem.objects.filter(
        order__customer=user, order__status=Order.Status.COMPLETED
    )
    top_items = (
        queryset.values('menu_item_id')
        .annotate(times_ordered=Count('id'))
        .order_by('-times_ordered')[:limit]
    )
    return [row['menu_item_id'] for row in top_items if row['menu_item_id']]