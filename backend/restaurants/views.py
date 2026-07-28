from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Restaurant, Category, MenuItem
from .serializers import (
    RestaurantSerializer, RestaurantDetailSerializer,
    CategorySerializer, MenuItemSerializer
)
from .permissions import IsOwnerOrReadOnly, CanCreateRestaurant, IsRestaurantOwnerOfItem


class RestaurantViewSet(viewsets.ModelViewSet):
    queryset = Restaurant.objects.filter(is_active=True)
    permission_classes = [CanCreateRestaurant, IsOwnerOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return RestaurantDetailSerializer
        return RestaurantSerializer

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def mine(self, request):
        restaurants = Restaurant.objects.filter(owner=request.user)
        serializer = RestaurantDetailSerializer(restaurants, many=True)
        return Response(serializer.data)


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsRestaurantOwnerOfItem]

    def get_queryset(self):
        queryset = Category.objects.all()
        restaurant_id = self.request.query_params.get('restaurant')
        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)
        return queryset


class MenuItemViewSet(viewsets.ModelViewSet):
    queryset = MenuItem.objects.all()
    serializer_class = MenuItemSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsRestaurantOwnerOfItem]

    def get_queryset(self):
        queryset = MenuItem.objects.all()

        # Only hide unavailable items for the public "list" browsing action.
        # Owners must still be able to retrieve/update/delete their own
        # items even while marked unavailable — otherwise toggling
        # availability off makes the item permanently stuck (404 on re-toggle).
        if self.action == 'list':
            queryset = queryset.filter(is_available=True)

        restaurant_id = self.request.query_params.get('restaurant')
        category_id = self.request.query_params.get('category')
        search = self.request.query_params.get('search')

        if restaurant_id:
            queryset = queryset.filter(restaurant_id=restaurant_id)
        if category_id:
            queryset = queryset.filter(category_id=category_id)
        if search:
            queryset = queryset.filter(name__icontains=search)

        return queryset