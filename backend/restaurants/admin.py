from django import forms
from django.contrib import admin
from django.contrib.auth import get_user_model
from .models import Restaurant, Category, MenuItem
from .models import Restaurant, Category, MenuItem, MenuItemVariant

User = get_user_model()




class RestaurantAdminForm(forms.ModelForm):
    # --- Used only when CREATING a new restaurant ---
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

    # --- Used only when EDITING an existing restaurant ---
    update_admin_username = forms.CharField(
        required=False,
        label="Restaurant Admin — Username",
        help_text="Change the username this restaurant's admin logs in with."
    )
    update_admin_email = forms.EmailField(required=False, label="Restaurant Admin — Email")
    update_admin_password = forms.CharField(
        required=False,
        widget=forms.PasswordInput,
        label="Restaurant Admin — New Password",
        help_text="Leave blank to keep the current password unchanged."
    )

    class Meta:
        model = Restaurant
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if 'owner' in self.fields:
            self.fields['owner'].required = False

        if self.instance and self.instance.pk and self.instance.owner:
            self.fields['update_admin_username'].initial = self.instance.owner.username
            self.fields['update_admin_email'].initial = self.instance.owner.email

    def clean(self):
        cleaned_data = super().clean()
        owner = cleaned_data.get('owner')
        username = cleaned_data.get('new_admin_username')
        password = cleaned_data.get('new_admin_password')

        if self.instance.pk is None:
            if not owner and not username:
                raise forms.ValidationError(
                    "Please fill in a Restaurant Admin username and password to create this restaurant's login."
                )
            if username:
                if not password:
                    raise forms.ValidationError("Please set a password for the Restaurant Admin.")
                if User.objects.filter(username=username).exists():
                    raise forms.ValidationError(f"Username '{username}' is already taken.")

        if self.instance.pk is not None and self.instance.owner:
            new_username = cleaned_data.get('update_admin_username')
            if new_username and new_username != self.instance.owner.username:
                if User.objects.filter(username=new_username).exclude(pk=self.instance.owner.pk).exists():
                    raise forms.ValidationError(f"Username '{new_username}' is already taken.")

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
        return base_fields + ['owner', 'update_admin_username', 'update_admin_email', 'update_admin_password']

    def save_model(self, request, obj, form, change):
        if not change:
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

        if change and obj.owner:
            new_username = form.cleaned_data.get('update_admin_username')
            new_email = form.cleaned_data.get('update_admin_email')
            new_password = form.cleaned_data.get('update_admin_password')

            admin_user = obj.owner
            changed = False

            if new_username and new_username != admin_user.username:
                admin_user.username = new_username
                changed = True
            if new_email is not None and new_email != admin_user.email:
                admin_user.email = new_email
                changed = True
            if new_password:
                admin_user.set_password(new_password)
                changed = True

            if changed:
                admin_user.save()


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'display_order']
    list_filter = ['restaurant']


class MenuItemVariantInline(admin.TabularInline):
    model = MenuItemVariant
    extra = 1


@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'category', 'price', 'is_available', 'stock_quantity']
    list_filter = ['restaurant', 'is_available', 'is_vegetarian']
    search_fields = ['name']
    inlines = [MenuItemVariantInline]

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)

        if obj is not None:
            form.base_fields['category'].queryset = Category.objects.filter(
                restaurant=obj.restaurant
            )
        else:
            form.base_fields['category'].queryset = Category.objects.select_related('restaurant')
            form.base_fields['category'].label_from_instance = (
                lambda obj: f"{obj.name} ({obj.restaurant.name})"
            )

        return form