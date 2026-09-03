import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/review_service.dart';
import 'food_review_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = OrderService.getMyOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = OrderService.getMyOrders();
    });
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
      case 'CANCELLED':
        return Colors.red;
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
        return 'Dine In';
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

  Widget _paymentBadge(OrderModel order) {
    if (order.paymentStatus == 'N/A') return const SizedBox.shrink();

    Color color;
    String label;
    switch (order.paymentStatus) {
      case 'PAID':
        color = Colors.green;
        label = 'Paid';
        break;
      case 'PENDING_CONFIRMATION':
        color = Colors.deepOrange;
        label = 'Payment Pending Confirmation';
        break;
      default:
        color = Colors.red;
        label = 'Unpaid';
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
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
                            // Step 2: immediately move into rating the individual food items.
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FoodReviewScreen(order: order)),
                            );
                            _refresh();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load orders: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, size: 60, color: AppColors.textGrey),
                          SizedBox(height: 12),
                          Text('No orders yet',
                              style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final sortedOrders = List<OrderModel>.from(orders)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedOrders.length,
              itemBuilder: (context, index) {
                final order = sortedOrders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order #${order.id}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (order.restaurantName.isNotEmpty)
                                Text(order.restaurantName,
                                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(order.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(order.status),
                            style: TextStyle(
                              color: _statusColor(order.status),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_orderTypeLabel(order.orderType)}'
                              '${order.tableNumber != null ? " · Table ${order.tableNumber}" : ""}'
                              ' · ${_formatDate(order.createdAt)}',
                              style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text('${item.quantity}x ${item.displayName}'),
                                      ),
                                      Text('Rs. ${item.subtotal.toStringAsFixed(0)}'),
                                    ],
                                  ),
                                )),
                            if (order.deliveryAddress.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Deliver to: ${order.deliveryAddress}',
                                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                            ],
                            if (order.contactPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Phone: ${order.contactPhone}',
                                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                            ],
                            if (order.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Notes: ${order.notes}',
                                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                            ],
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Rs. ${order.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            _paymentBadge(order),
                            if (order.status == 'COMPLETED' && !order.hasReview) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.star_border, size: 18),
                                  label: const Text('Rate this order'),
                                  onPressed: () => _showRatingDialog(order),
                                ),
                              ),
                            ] else if (order.status == 'COMPLETED' && order.hasReview) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.star, size: 16, color: Colors.green),
                                    SizedBox(width: 6),
                                    Text(
                                      'Reviewed',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}