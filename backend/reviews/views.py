from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Review, FoodReview
from .serializers import (
    ReviewSerializer, ReviewCreateSerializer,
    FoodReviewSerializer, FoodReviewCreateSerializer
)


class ReviewViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'create':
            return ReviewCreateSerializer
        return ReviewSerializer

    def get_queryset(self):
        queryset = Review.objects.all()
        user = self.request.user

        if user.is_authenticated and user.role == 'RESTAURANT_ADMIN':
            queryset = queryset.filter(restaurant__owner=user)
        else:
            restaurant_id = self.request.query_params.get('restaurant')
            if restaurant_id:
                queryset = queryset.filter(restaurant_id=restaurant_id)
            if self.request.query_params.get('mine') and user.is_authenticated:
                queryset = queryset.filter(customer=user)

        return queryset

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        review = serializer.save()
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.customer != request.user:
            return Response({"detail": "Not your review."}, status=status.HTTP_403_FORBIDDEN)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.customer != request.user:
            return Response({"detail": "Not your review."}, status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def reply(self, request, pk=None):
        review = self.get_object()
        if review.restaurant.owner != request.user:
            return Response({"detail": "Only the restaurant owner can reply."}, status=status.HTTP_403_FORBIDDEN)
        reply_text = (request.data.get('reply') or '').strip()
        if not reply_text:
            return Response({"detail": "Reply cannot be empty."}, status=status.HTTP_400_BAD_REQUEST)
        review.restaurant_reply = reply_text
        review.save()
        return Response(ReviewSerializer(review).data)


class FoodReviewViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'create':
            return FoodReviewCreateSerializer
        return FoodReviewSerializer

    def get_queryset(self):
        queryset = FoodReview.objects.all()
        user = self.request.user

        if user.is_authenticated and user.role == 'RESTAURANT_ADMIN':
            queryset = queryset.filter(order_item__order__restaurant__owner=user)
        else:
            menu_item_id = self.request.query_params.get('menu_item')
            if menu_item_id:
                queryset = queryset.filter(menu_item_id=menu_item_id)
            if self.request.query_params.get('mine') and user.is_authenticated:
                queryset = queryset.filter(customer=user)

        return queryset

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        review = serializer.save()
        return Response(FoodReviewSerializer(review).data, status=status.HTTP_201_CREATED)