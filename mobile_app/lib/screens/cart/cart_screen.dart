import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../services/promotion_service.dart';
import '../../utils/table_number_utils.dart';
import '../../widgets/payment_confirm_dialog.dart';
import '../checkout/card_payment_webview_screen.dart';
import '../../services/location_service.dart';
import '../checkout/location_picker_screen.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import 'dart:ui';

class CartScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const CartScreen({super.key, required this.restaurant});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _orderType = 'TAKEAWAY';
  String _paymentMethod = 'CASH';
  final _tableNumberController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _promoCodeController = TextEditingController();

  bool _placing = false;
  bool _initializedFromCart = false;
  bool _isTableFlow = false;
  bool _resolvingAwaitingOrder = false;
  bool _checkingAwaitingOrder = true;

  String? _appliedPromoCode;
  double _discountAmount = 0;
  String? _promoTitle;
  bool _validatingPromo = false;

  int get _restaurantId => widget.restaurant.id;

  double? _deliveryLatitude;
  double? _deliveryLongitude;

  final _alternativePhoneController = TextEditingController();
  bool _deliveryFieldsPrefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      _verifyAwaitingOrder(cart);
    });
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _deliveryAddressController.dispose();
    _contactPhoneController.dispose();
    _alternativePhoneController.dispose();
    _notesController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Map<String, String> get _availableOrderTypes {
    final r = widget.restaurant;
    final types = <String, String>{};

    if (r.supportsDineIn) types['DINE_IN'] = 'Dine In';
    if (r.supportsTakeaway) types['TAKEAWAY'] = 'Takeaway';
    if (r.supportsDelivery) types['DELIVERY'] = 'Delivery';
    return types;
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'DINE_IN':
        return 'Dine In';
      case 'TAKEAWAY':
        return 'Takeaway';
      case 'DELIVERY':
        return 'Delivery';
      default:
        return type;
    }
  }

  /// Confirms an "awaiting payment" order tracked locally for this
  /// restaurant is actually still real, still unpaid, AND actually
  /// belongs to THIS restaurant before showing the blocker screen.
  /// Prevents stale/mismatched local tracking (e.g. from earlier testing)
  /// from permanently blocking a genuinely fresh checkout.
  Future<void> _verifyAwaitingOrder(CartProvider cart) async {
    final awaitingId = cart.awaitingOrderIdFor(_restaurantId);
    if (awaitingId == null) {
      setState(() => _checkingAwaitingOrder = false);
      return;
    }

    try {
      final orders = await OrderService.getMyOrders();
      final order = orders.where((o) => o.id == awaitingId).firstOrNull;

      if (order == null ||
          order.status != 'AWAITING_PAYMENT' ||
          order.restaurantId != _restaurantId) {
        // Stale tracking — the order doesn't exist anymore, was already
        // resolved some other way, or (most likely bug) belongs to a
        // DIFFERENT restaurant than this one. Clear it silently instead
        // of showing a confusing/incorrect blocker.
        cart.clearAwaitingOrder(_restaurantId);
      }
    } catch (_) {
      // If we can't verify right now, don't block checkout on a network
      // hiccup — fail open and let the customer proceed normally.
      cart.clearAwaitingOrder(_restaurantId);
    }

    if (mounted) setState(() => _checkingAwaitingOrder = false);
  }

  Future<void> _applyPromoCode(RestaurantCartData myCart) async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _validatingPromo = true);
    final result = await PromotionService.validateCode(
      restaurantId: _restaurantId,
      code: code,
      subtotal: myCart.totalAmount,
    );
    setState(() => _validatingPromo = false);

    if (result['success']) {
      setState(() {
        _appliedPromoCode = code;
        _discountAmount = double.parse(result['discount_amount'].toString());
        _promoTitle = result['title'];
      });
    } else {
      setState(() {
        _appliedPromoCode = null;
        _discountAmount = 0;
        _promoTitle = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'].toString())),
        );
      }
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromoCode = null;
      _discountAmount = 0;
      _promoTitle = null;
      _promoCodeController.clear();
    });
  }

  double _totalDue(RestaurantCartData myCart) => myCart.totalAmount - _discountAmount;

  Future<void> _onContinue(CartProvider cart, RestaurantCartData myCart) async {
    if (_orderType == 'DELIVERY') {
      if (_deliveryAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a delivery address')),
        );
        return;
      }
      if (_contactPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a contact phone number')),
        );
        return;
      }
    }
    if (_orderType == 'DINE_IN' && _tableNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your table number')),
      );
      return;
    }

    String paymentMethodLabel;
    String? confirmNote;

    if (_orderType == 'DINE_IN') {
      paymentMethodLabel = 'Added to table bill';
    } else if (_paymentMethod == 'CARD') {
      paymentMethodLabel = 'Card';
      confirmNote = 'You will be redirected to a secure payment page to pay online now.';
    } else if (_orderType == 'DELIVERY') {
      paymentMethodLabel = 'Cash on Delivery';
      confirmNote = 'Please have Rs. ${_totalDue(myCart).toStringAsFixed(0)} ready to pay the rider in cash when your order arrives.';
    } else {
      paymentMethodLabel = 'Cash';
      confirmNote = 'Please pay in cash when you collect your order at the restaurant.';
    }

    final confirmed = await showPaymentConfirmDialog(
      context: context,
      restaurantName: widget.restaurant.name,
      orderTypeLabel: _orderTypeLabel(_orderType),
      totalAmount: _totalDue(myCart),
      paymentMethodLabel: paymentMethodLabel,
      note: confirmNote,
    );
    if (!confirmed) return;

    if (!mounted) return;
    await _placeOrder(cart, myCart);
  }

  Future<void> _placeOrder(CartProvider cart, RestaurantCartData myCart) async {
    setState(() => _placing = true);

    // For Delivery orders, silently capture the customer's current GPS
    // location right before placing the order — no button, no visible
    // step. If it fails (permission denied, GPS off, etc.) we simply
    // proceed without it; the typed address is still required and used.
    if (_orderType == 'DELIVERY' && _deliveryLatitude == null) {
      final locationResult = await LocationService.getCurrentLocation();
      if (locationResult['success']) {
        final location = locationResult['result'] as LocationResult;
        _deliveryLatitude = location.latitude;
        _deliveryLongitude = location.longitude;
      }
    }

    final items = myCart.items.values
        .map((cartItem) => {
              'menu_item': cartItem.menuItem.id,
              if (cartItem.variant != null) 'variant': cartItem.variant!.id,
              'quantity': cartItem.quantity,
            })
        .toList();

    final normalizedTable = normalizeTableNumber(_tableNumberController.text);

    final result = await OrderService.createOrder(
      restaurantId: _restaurantId,
      orderType: _orderType,
      items: items,
      deliveryAddress: _deliveryAddressController.text.trim(),
      deliveryLatitude: _deliveryLatitude,
      deliveryLongitude: _deliveryLongitude,
      contactPhone: _contactPhoneController.text.trim(),
      alternativePhone: _alternativePhoneController.text.trim(),
      tableNumber: normalizedTable,
      notes: [_notesController.text.trim(), myCart.buildItemNotesSummary()]
          .where((s) => s.isNotEmpty)
          .join('\n'),
      promoCode: _appliedPromoCode ?? '',
      paymentMethod: _orderType == 'DINE_IN' ? 'CASH' : _paymentMethod,
    );

    if (!result['success']) {
      setState(() => _placing = false);
      if (!mounted) return;
      final error = result['error'];
      String message = 'Failed to place order';
      if (error is Map) {
        message = error.values.first.toString();
      } else if (error is List) {
        message = error.first.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final order = result['order'];

    if (_orderType != 'DINE_IN' && _paymentMethod == 'CARD') {
      // Deliberately keep _placing = true (screen stays locked/blurred)
      // through the ENTIRE card flow — creating the checkout session AND
      // opening the gateway — not just order creation. This closes the
      // window where a second tap on Continue could slip through and
      // create a duplicate order before the gateway even appears.
      await _openCardPayment(cart, order.id, order.latestPaymentId, order);
      if (mounted) setState(() => _placing = false);
      return;
    }

    cart.clearRestaurant(_restaurantId);
    setState(() => _placing = false);
    if (!mounted) return;
    _showSuccessDialog(order);
  }

  Future<void> _openCardPayment(CartProvider cart, int orderId, int? paymentId, dynamic order) async {
    if (paymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start payment. Please try again.')),
      );
      return;
    }

    final sessionResult = await OrderService.createCheckoutSession(paymentId);
    if (!mounted) return;

    if (!sessionResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sessionResult['error'].toString())),
      );
      return;
    }
    final paid = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => CardPaymentWebViewScreen(
          checkoutUrl: sessionResult['checkoutUrl'],
          paymentId: paymentId,
        ),
      ),
    );

    if (!mounted) return;

    if (paid == true) {
      cart.clearAwaitingOrder(_restaurantId);
      cart.clearRestaurant(_restaurantId);
      _showSuccessDialog(order);
    } else {
      // Payment was NOT completed — only NOW do we mark this order as
      // awaiting payment. This is what keeps a fresh, successful checkout
      // flow completely free of any intermediate screen, while still
      // correctly protecting against duplicate orders on retry.
      cart.setAwaitingOrder(_restaurantId, orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment was not completed. Use "Pay Now" below to try again, or cancel this order.',
          ),
        ),
      );
    }
  }

  Future<void> _retryPayNow(CartProvider cart, int orderId) async {
    setState(() => _resolvingAwaitingOrder = true);

    final orders = await OrderService.getMyOrders();
    final order = orders.where((o) => o.id == orderId).firstOrNull;

    setState(() => _resolvingAwaitingOrder = false);

    if (order == null || !mounted) {
      cart.clearAwaitingOrder(_restaurantId);
      return;
    }
    if (order.status != 'AWAITING_PAYMENT') {
      cart.clearAwaitingOrder(_restaurantId);
      setState(() {});
      return;
    }

    String paymentMethod = 'CARD';
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Pay Order #${order.id}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  PaymentMethodSelector(
                    selected: paymentMethod,
                    onChanged: (value) => setDialogState(() => paymentMethod = value),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, paymentMethod),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
    if (chosen == null) return;

    if (chosen == 'CASH') {
      setState(() => _resolvingAwaitingOrder = true);
      final result = await OrderService.requestCashForOrder(order.id);
      setState(() => _resolvingAwaitingOrder = false);

      if (!mounted) return;
      if (result['success']) {
        cart.clearAwaitingOrder(_restaurantId);
        cart.clearRestaurant(_restaurantId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please pay at the counter. Your order is now pending confirmation.'),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'].toString())),
        );
      }
      return;
    }

    await _openCardPayment(cart, order.id, order.latestPaymentId, order);
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _deliveryLatitude,
          initialLongitude: _deliveryLongitude,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _deliveryLatitude = result.latitude;
      _deliveryLongitude = result.longitude;
      if (result.address.isNotEmpty) {
        _deliveryAddressController.text = result.address;
      }
    });
  }

  Future<void> _cancelAwaitingOrder(CartProvider cart, int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this unpaid order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _resolvingAwaitingOrder = true);
    final result = await OrderService.cancelOrder(orderId);
    setState(() => _resolvingAwaitingOrder = false);

    if (!mounted) return;

    if (result['success']) {
      cart.clearAwaitingOrder(_restaurantId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled. You can place a new order below.')),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
    }
  }

  void _showSuccessDialog(dynamic order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Order Placed!'),
        content: Text(
          order.orderType == 'DINE_IN'
              ? 'Your order #${order.id} has been sent to the kitchen. It has been added to your table\'s bill — pay anytime from "My Activity".'
              : 'Your order #${order.id} has been placed successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingOrderBlocker(CartProvider cart, int orderId) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions, size: 56, color: Colors.deepOrange),
          const SizedBox(height: 16),
          Text(
            'Order #$orderId is awaiting payment',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete payment for this order, or cancel it, before placing a new one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_resolvingAwaitingOrder)
            const CircularProgressIndicator()
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _retryPayNow(cart, orderId),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Pay Now'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelAwaitingOrder(cart, orderId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel Order'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartForm(CartProvider cart, RestaurantCartData myCart) {
    final orderTypes = _availableOrderTypes;
    if (orderTypes.isNotEmpty && !orderTypes.containsKey(_orderType)) {
      _orderType = orderTypes.keys.first;
    }

    if (orderTypes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This restaurant is not currently accepting orders.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...myCart.items.entries.map((entry) {
          final key = entry.key;
          final cartItem = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(cartItem.displayName),
              subtitle: Text('Rs. ${cartItem.unitPrice.toStringAsFixed(0)} x ${cartItem.quantity}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => cart.decrementByKey(_restaurantId, key),
                  ),
                  Text('${cartItem.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => cart.incrementByKey(_restaurantId, key),
                  ),
                ],
              ),
            ),
          );
        }),
        const Divider(height: 32),
        const Text('Order Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: orderTypes.entries.map((e) {
            return ChoiceChip(
              label: Text(e.value),
              selected: _orderType == e.key,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _orderType == e.key ? Colors.white : AppColors.textDark,
              ),
              onSelected: (_) => setState(() {
                _orderType = e.key;
                if (e.key == 'DELIVERY' && !_deliveryFieldsPrefilled) {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  if (authProvider.user != null) {
                    final currentUser = UserModel.fromJson(authProvider.user!);
                    if (_deliveryAddressController.text.isEmpty && currentUser.address.isNotEmpty) {
                      _deliveryAddressController.text = currentUser.address;
                    }
                    if (_contactPhoneController.text.isEmpty && currentUser.phoneNumber.isNotEmpty) {
                      _contactPhoneController.text = currentUser.phoneNumber;
                    }
                    _deliveryFieldsPrefilled = true;
                  }
                }
              }),
            );
          }).toList(),
        ),
        if (_orderType == 'DINE_IN') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _tableNumberController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Table Number',
              hintText: 'e.g. 3 or 05',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.table_bar),
            ),
            onEditingComplete: () {
              _tableNumberController.text = normalizeTableNumber(_tableNumberController.text);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'This order will be added to your table\'s bill. You can pay anytime from "My Activity".',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ],
        if (_orderType == 'DELIVERY') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _deliveryAddressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Delivery Address',
              hintText: 'House number, street, city',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openLocationPicker,
            icon: Icon(
              _deliveryLatitude != null ? Icons.check_circle : Icons.map_outlined,
              size: 18,
              color: _deliveryLatitude != null ? Colors.green : null,
            ),
            label: Text(
              _deliveryLatitude != null ? 'Location Set — Change on Map' : 'Choose Exact Location on Map',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact Phone Number',
              hintText: 'e.g. 0771234567',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alternativePhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Alternative Phone Number (optional)',
              hintText: 'Backup number, in case we can\'t reach you',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_forwarded_outlined),
            ),
          ),
        ],
        if (_orderType != 'DINE_IN') ...[
          const SizedBox(height: 20),
          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          PaymentMethodSelector(
            selected: _paymentMethod,
            onChanged: (value) => setState(() => _paymentMethod = value),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        const Text('Promo Code', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_appliedPromoCode != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_promoTitle ?? _appliedPromoCode} applied (-Rs. ${_discountAmount.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _removePromoCode,
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter promo code',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _validatingPromo
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () => _applyPromoCode(myCart),
                      child: const Text('Apply'),
                    ),
            ],
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal', style: TextStyle(fontSize: 14)),
            Text('Rs. ${myCart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14)),
          ],
        ),
        if (_discountAmount > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discount', style: TextStyle(fontSize: 14, color: Colors.green)),
              Text('-Rs. ${_discountAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14, color: Colors.green)),
            ],
          ),
        ],
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Rs. ${_totalDue(myCart).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        _placing
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: () => _onContinue(cart, myCart),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final myCart = cart.cartFor(_restaurantId);
    final awaitingOrderId = cart.awaitingOrderIdFor(_restaurantId);

    if (!_initializedFromCart) {
      if (cart.pendingTableNumber != null) {
        _orderType = 'DINE_IN';
        _tableNumberController.text = cart.pendingTableNumber!;
        _isTableFlow = true;
      } else if (cart.isQRFlow) {
        _orderType = 'DINE_IN';
        _isTableFlow = true;
      }
      _initializedFromCart = true;
    }

    Widget body;
    if (_checkingAwaitingOrder) {
      body = const Center(child: CircularProgressIndicator());
    } else if (awaitingOrderId != null) {
      body = _buildAwaitingOrderBlocker(cart, awaitingOrderId);
    } else if (myCart == null || myCart.isEmpty) {
      body = const Center(child: Text('Your cart is empty'));
    } else {
      body = _buildCartForm(cart, myCart);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurant.name)),
      body: Stack(
        children: [
          body,
          if (_placing)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.15),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}