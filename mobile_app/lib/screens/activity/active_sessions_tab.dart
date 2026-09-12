import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/table_session_model.dart';
import '../../models/order_model.dart';
import '../../services/table_session_service.dart';
import '../../services/order_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/review_service.dart';
import '../../providers/cart_provider.dart';
import '../restaurant/restaurant_detail_screen.dart';
import '../orders/food_review_screen.dart';
import '../../widgets/payment_confirm_dialog.dart';
import '../checkout/card_payment_webview_screen.dart';
import '../orders/track_delivery_screen.dart';

class ActiveSessionsTab extends StatefulWidget {
  final CartProvider cart;
  const ActiveSessionsTab({super.key, required this.cart});

  @override
  State<ActiveSessionsTab> createState() => ActiveSessionsTabState();
}

class ActiveSessionsTabState extends State<ActiveSessionsTab> {
  late Future<List<TableSessionModel>> _sessionsFuture;
  late Future<List<OrderModel>> _ordersFuture;
  int? _payingSessionId;
  int? _loadingAddMoreId;
  int? _actingOnOrderId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _sessionsFuture = TableSessionService.getActiveSessions();
    _ordersFuture = OrderService.getMyOrders();
  }

  Future<void> refresh() async {
    setState(_loadAll);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'AWAITING_PAYMENT':
        return Colors.redAccent;
      case 'PAYMENT_PENDING':
        return Colors.deepOrange;
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PREPARING':
        return Colors.purple;
      case 'READY':
        return Colors.teal;
      case 'OUT_FOR_DELIVERY':
        return Colors.indigo;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'DINE_IN':
        return 'Dine-In';
      case 'TAKEAWAY':
        return 'Takeaway';
      case 'DELIVERY':
        return 'Delivery';
      default:
        return type;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _addMoreFood(TableSessionModel session) async {
    setState(() => _loadingAddMoreId = session.id);
    try {
      final restaurant = await RestaurantService.getRestaurantDetail(session.restaurantId);
      if (!mounted) return;
      widget.cart.setPendingTableNumber(restaurant.id, restaurant.name, session.tableNumber);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurantId: restaurant.id)),
      );
      refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open menu: $e')));
    } finally {
      if (mounted) setState(() => _loadingAddMoreId = null);
    }
  }

  Future<void> _payTableNow(TableSessionModel session) async {
    String paymentMethod = 'CASH';

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Pay Table Bill'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Table ${session.tableNumber} · ${session.restaurantName}',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                  const SizedBox(height: 16),
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

    if (!mounted) return;
    final confirmed = await showPaymentConfirmDialog(
      context: context,
      restaurantName: session.restaurantName,
      orderTypeLabel: 'Dine-In',
      totalAmount: session.totalAmount,
      paymentMethodLabel: chosen == 'CASH' ? 'Cash' : 'Card',
    );
    if (!confirmed) return;

    setState(() => _payingSessionId = session.id);
    final result = await TableSessionService.paySession(session.id, paymentMethod: chosen);
    setState(() => _payingSessionId = null);

    if (!mounted) return;

    if (!result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request failed. Please try again.')),
      );
      return;
    }

    if (chosen == 'CASH') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment requested. Please pay at the counter.')),
      );
      refresh();
      return;
    }

    final paymentId = result['paymentId'];
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(paid == true
          ? 'Payment successful! Thank you.'
          : 'Payment was not completed. You can try again from "Pay Now".')),
    );
    refresh();
  }

  // --- Order-level actions (Takeaway / Delivery) ---

  Future<void> _payNowForOrder(OrderModel order) async {
    if (order.latestPaymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment found for this order.')),
      );
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
                  Text('${order.restaurantName} · Rs. ${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                  const SizedBox(height: 16),
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
      setState(() => _actingOnOrderId = order.id);
      final result = await OrderService.requestCashForOrder(order.id);
      setState(() => _actingOnOrderId = null);

      if (!mounted) return;
      if (result['success']) {
        widget.cart.clearAwaitingOrder(order.restaurantId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pay at the counter. Your order is now pending confirmation.')),
        );
        refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'].toString())),
        );
      }
      return;
    }

    // Card — same as before.
    setState(() => _actingOnOrderId = order.id);
    final sessionResult = await OrderService.createCheckoutSession(order.latestPaymentId!);
    setState(() => _actingOnOrderId = null);

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
          paymentId: order.latestPaymentId!,
        ),
      ),
    );

    if (!mounted) return;

    if (paid == true) {
      widget.cart.clearAwaitingOrder(order.restaurantId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment was not completed. You can try again anytime.')),
      );
    }
    refresh();
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel order #${order.id}?'),
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

    setState(() => _actingOnOrderId = order.id);
    final result = await OrderService.cancelOrder(order.id);
    setState(() => _actingOnOrderId = null);

    if (!mounted) return;

    if (result['success']) {
      widget.cart.clearAwaitingOrder(order.restaurantId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
      refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
    }
  }

  Future<void> _showRatingDialog(OrderModel order) async {
    int selectedRating = 5;
    final commentController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Rate your order at ${order.restaurantName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () => setDialogState(() => selectedRating = starValue),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: 'Share your experience (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                submitting
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => submitting = true);
                          final result = await ReviewService.submitReview(
                            orderId: order.id,
                            rating: selectedRating,
                            comment: commentController.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          if (result['success']) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thanks for your review!')),
                            );
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FoodReviewScreen(order: order)),
                            );
                            refresh();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result['error'].toString())),
                            );
                          }
                        },
                        child: const Text('Submit'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyNote(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(text, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
    );
  }

  Widget _dineInSessionCard(TableSessionModel session) {
    final isPaymentPending = session.status == 'PAYMENT_PENDING';
    final isPaying = _payingSessionId == session.id;
    final isAddingMore = _loadingAddMoreId == session.id;
    final accentColor = isPaymentPending ? Colors.deepOrange : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.restaurantName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Dine-In · Table ${session.tableNumber}',
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPaymentPending ? Colors.deepOrange : Colors.blue).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPaymentPending ? 'Payment Pending' : 'Open',
                    style: TextStyle(
                      color: isPaymentPending ? Colors.deepOrange : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...session.orders.map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #${order.id} · ${_statusLabel(order.status)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text('${item.quantity}x ${item.displayName}',
                                        style: const TextStyle(fontSize: 13))),
                                Text('Rs. ${item.subtotal.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          )),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Rs. ${session.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            if (isPaymentPending)
              const Text('Waiting for the restaurant to confirm your payment.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: isAddingMore
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add, size: 16),
                      label: const Text('Add More Food', style: TextStyle(fontSize: 12)),
                      onPressed: isAddingMore ? null : () => _addMoreFood(session),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isPaying
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _payTableNow(session),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                            child: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _activeOrderCard(OrderModel order) {
    final accentColor = _statusColor(order.status);
    final isActing = _actingOnOrderId == order.id;
    final isAwaitingPayment = order.status == 'AWAITING_PAYMENT';
    final isCancellable = ['AWAITING_PAYMENT', 'PAYMENT_PENDING', 'PENDING'].contains(order.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.restaurantName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${_orderTypeLabel(order.orderType)} · Order #${order.id} · ${_formatDate(order.createdAt)}',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(order.status),
                    style: TextStyle(color: _statusColor(order.status), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (order.orderType == 'DELIVERY' && order.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍 ${order.deliveryAddress}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ],
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item.quantity}x ${item.displayName}', style: const TextStyle(fontSize: 13))),
                      Text('Rs. ${item.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Rs. ${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            if (order.orderType == 'DELIVERY' && order.status == 'OUT_FOR_DELIVERY') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TrackDeliveryScreen(orderId: order.id)),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Track Order', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ],
            if (isCancellable) ...[
              const SizedBox(height: 10),
              if (isActing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    if (isAwaitingPayment) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _payNowForOrder(order),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                          child: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelOrder(order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pastOrderCard(OrderModel order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.restaurantName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${_orderTypeLabel(order.orderType)} · ${_formatDate(order.createdAt)}',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textGrey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Completed',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item.quantity}x ${item.displayName}', style: const TextStyle(fontSize: 13))),
                      Text('Rs. ${item.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Rs. ${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            if (!order.hasReview)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.star_border, size: 16),
                  label: const Text('Rate Order', style: TextStyle(fontSize: 13)),
                  onPressed: () => _showRatingDialog(order),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.green),
                    SizedBox(width: 6),
                    Text('Reviewed', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder(
        future: Future.wait([_sessionsFuture, _ordersFuture]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load: ${snapshot.error}'),
              ),
            ]);
          }

          final sessions = (snapshot.data![0] as List<TableSessionModel>);
          final allOrders = (snapshot.data![1] as List<OrderModel>);

          final activeTakeaway = allOrders
              .where((o) => o.orderType == 'TAKEAWAY' && !['COMPLETED', 'CANCELLED'].contains(o.status))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final activeDelivery = allOrders
              .where((o) => o.orderType == 'DELIVERY' && !['COMPLETED', 'CANCELLED'].contains(o.status))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final pastOrders = allOrders.where((o) => o.status == 'COMPLETED').toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final hasAnyActive = sessions.isNotEmpty || activeTakeaway.isNotEmpty || activeDelivery.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _sectionHeader('Active Orders'),
              if (!hasAnyActive)
                _emptyNote('No active orders right now.')
              else ...[
                ...sessions.map(_dineInSessionCard),
                ...activeTakeaway.map(_activeOrderCard),
                ...activeDelivery.map(_activeOrderCard),
              ],

              _sectionHeader('Past Orders'),
              if (pastOrders.isEmpty)
                _emptyNote('No completed orders yet.')
              else
                ...pastOrders.map(_pastOrderCard),
            ],
          );
        },
      ),
    );
  }
}