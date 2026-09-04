from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from restaurants.models import MenuItem
from restaurants.serializers import MenuItemSerializer
from .engine import recommend_for_user, get_popular_items, get_reorder_items


def _serialize_with_reason(results):
    """Takes [{'item_id': .., 'reason': ..}, ...], preserves order, attaches
    the reason string onto each serialized menu item."""
    item_ids = [r['item_id'] for r in results]
    reason_by_id = {r['item_id']: r['reason'] for r in results}

    items = MenuItem.objects.filter(id__in=item_ids, is_available=True)
    items_by_id = {item.id: item for item in items}

    output = []
    for item_id in item_ids:
        item = items_by_id.get(item_id)
        if not item:
            continue
        data = MenuItemSerializer(item).data
        data['recommendation_reason'] = reason_by_id.get(item_id)
        output.append(data)

    return output


class RecommendationsForMeView(APIView):
    """Personalized 'Recommended for You' — spans all restaurants."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        limit = int(request.query_params.get('limit', 10))

        results = recommend_for_user(request.user, restaurant_id=None, limit=limit)
        if not results:
            results = get_popular_items(limit=limit)

        return Response(_serialize_with_reason(results))


class RestaurantRecommendationsView(APIView):
    """'You might also like' scoped to one restaurant's menu."""
    permission_classes = [AllowAny]

    def get(self, request, restaurant_id):
        limit = int(request.query_params.get('limit', 6))

        results = None
        if request.user.is_authenticated:
            results = recommend_for_user(request.user, restaurant_id=restaurant_id, limit=limit)
        if not results:
            results = get_popular_items(restaurant_id=restaurant_id, limit=limit)

        return Response(_serialize_with_reason(results))


class OrderAgainView(APIView):
    """The customer's own repeat items — 'Order It Again' shortcut."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        limit = int(request.query_params.get('limit', 10))
        item_ids = get_reorder_items(request.user, limit=limit)

        items = MenuItem.objects.filter(id__in=item_ids, is_available=True)
        items_by_id = {item.id: item for item in items}
        ordered_items = [items_by_id[i] for i in item_ids if i in items_by_id]

        return Response(MenuItemSerializer(ordered_items, many=True).data)