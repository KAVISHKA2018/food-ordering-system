from django import forms
from django.contrib import admin
from django.contrib.auth import get_user_model
from .models import Restaurant, Category, MenuItem

User = get_user_model()


class RestaurantAdminForm(forms.ModelForm):
    new_admin_username = forms.CharField(
        required=False,
        label="Restaurant Admin — Username",
        help_text="Creates the login this restaurant's admin will use for the React admin panel."
    )
    new_admin_email = forms.EmailField(required=False, label="Restaurant Admin — Email")
    new_admin_password = forms.CharField(
        required=False,
        widget=forms.PasswordInput,
        label="Restaurant Admin — Password"
    )

    class Meta:
        model = Restaurant
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if 'owner' in self.fields:
            self.fields['owner'].required = False

    def clean(self):
        cleaned_data = super().clean()
        owner = cleaned_data.get('owner')
        username = cleaned_data.get('new_admin_username')
        password = cleaned_data.get('new_admin_password')

        if not owner and not username:
            raise forms.ValidationError(
                "Please fill in a Restaurant Admin username and password to create this restaurant's login."
            )
        if username:
            if not password:
                raise forms.ValidationError("Please set a password for the Restaurant Admin.")
            if User.objects.filter(username=username).exists():
                raise forms.ValidationError(f"Username '{username}' is already taken.")
        return cleaned_data


@admin.register(Restaurant)
class RestaurantAdmin(admin.ModelAdmin):
    form = RestaurantAdminForm
    list_display = ['name', 'owner', 'is_active', 'created_at']
    list_filter = ['is_active']
    search_fields = ['name']

    def get_fields(self, request, obj=None):
        base_fields = [
            'name', 'description', 'address', 'phone_number', 'email',
            'logo', 'cover_image', 'opening_time', 'closing_time', 'is_active',
        ]
        if obj is None:
            return base_fields + ['new_admin_username', 'new_admin_email', 'new_admin_password']
        return base_fields + ['owner']

    def save_model(self, request, obj, form, change):
        username = form.cleaned_data.get('new_admin_username')
        password = form.cleaned_data.get('new_admin_password')
        email = form.cleaned_data.get('new_admin_email')

        if username and password:
            new_admin = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                role='RESTAURANT_ADMIN',
            )
            obj.owner = new_admin

        super().save_model(request, obj, form, change)


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'display_order']
    list_filter = ['restaurant']


@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'category', 'price', 'is_available', 'stock_quantity']
    list_filter = ['restaurant', 'is_available', 'is_vegetarian']
    search_fields = ['name']