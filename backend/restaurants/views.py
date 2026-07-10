from rest_framework import viewsets, permissions
from .models import Restaurant, Category, MenuItem
from .serializers import (
    RestaurantSerializer, RestaurantDetailSerializer,
    CategorySerializer, MenuItemSerializer
)
from .permissions import IsOwnerOrReadOnly, IsRestaurantAdmin, IsRestaurantOwnerOfItem

from rest_framework.decorators import action
from rest_framework.response import Response


class RestaurantViewSet(viewsets.ModelViewSet):
    queryset = Restaurant.objects.filter(is_active=True)
    permission_classes = [IsRestaurantAdmin, IsOwnerOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return RestaurantDetailSerializer
        return RestaurantSerializer

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def mine(self, request):
        """Returns only the restaurant(s) owned by the logged-in admin."""
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
        queryset = MenuItem.objects.filter(is_available=True)
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