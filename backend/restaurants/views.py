import qrcode
from io import BytesIO
from django.http import HttpResponse
from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Restaurant, Category, MenuItem
from .serializers import (
    RestaurantSerializer, RestaurantDetailSerializer,
    CategorySerializer, MenuItemSerializer
)
from .permissions import IsOwnerOrReadOnly, CanCreateRestaurant, IsRestaurantOwnerOfItem

from .models import Restaurant, Category, MenuItem, MenuItemVariant
from .serializers import (
    RestaurantSerializer, RestaurantDetailSerializer,
    CategorySerializer, MenuItemSerializer, MenuItemVariantSerializer
)
from .permissions import (
    IsOwnerOrReadOnly, CanCreateRestaurant,
    IsRestaurantOwnerOfItem, IsRestaurantOwnerOfVariant
)


class MenuItemVariantViewSet(viewsets.ModelViewSet):
    queryset = MenuItemVariant.objects.all()
    serializer_class = MenuItemVariantSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsRestaurantOwnerOfVariant]

    def get_queryset(self):
        queryset = MenuItemVariant.objects.all()
        menu_item_id = self.request.query_params.get('menu_item')
        if menu_item_id:
            queryset = queryset.filter(menu_item_id=menu_item_id)
        return queryset


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

    @action(detail=True, methods=['get'], url_path='qr-code', permission_classes=[permissions.IsAuthenticated])
    def qr_code(self, request, pk=None):
        """Returns a PNG QR code encoding this restaurant's ID.
        Customers scan it to jump straight into dine-in ordering for this restaurant."""
        restaurant = self.get_object()

        if restaurant.owner != request.user and not request.user.is_staff:
            return Response({"detail": "Not authorized."}, status=status.HTTP_403_FORBIDDEN)

        qr_content = f"foodorder://restaurant/{restaurant.id}"
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(qr_content)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)

        response = HttpResponse(buffer.getvalue(), content_type="image/png")
        response['Content-Disposition'] = f'inline; filename="restaurant_{restaurant.id}_qr.png"'
        return response


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