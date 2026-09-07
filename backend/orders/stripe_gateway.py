import stripe
from django.conf import settings

stripe.api_key = settings.STRIPE_SECRET_KEY


def create_checkout_session(payment, restaurant_name):
    """Creates a Stripe-hosted checkout page for this payment and returns
    its URL. Stripe handles all card entry — we never see card details."""
    unit_amount = int(round(float(payment.amount) * 100))  # smallest currency unit

    session = stripe.checkout.Session.create(
        payment_method_types=['card'],
        line_items=[{
            'price_data': {
                'currency': 'lkr',
                'product_data': {'name': f'Order at {restaurant_name}'},
                'unit_amount': unit_amount,
            },
            'quantity': 1,
        }],
        mode='payment',
        success_url=f'{settings.PUBLIC_BASE_URL}/api/stripe-return/?session_id={{CHECKOUT_SESSION_ID}}',
        cancel_url=f'{settings.PUBLIC_BASE_URL}/api/stripe-cancel/',
        client_reference_id=str(payment.id),
        metadata={'payment_id': str(payment.id)},
    )
    payment.gateway_reference = session.id
    payment.save()
    return session.url