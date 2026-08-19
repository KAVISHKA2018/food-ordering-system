import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/table_session_model.dart';
import '../../services/table_session_service.dart';
import '../../services/restaurant_service.dart';
import '../../providers/cart_provider.dart';
import '../restaurant/restaurant_detail_screen.dart';

class MyTableScreen extends StatefulWidget {
  const MyTableScreen({super.key});

  @override
  State<MyTableScreen> createState() => _MyTableScreenState();
}

class _MyTableScreenState extends State<MyTableScreen> {
  late Future<List<TableSessionModel>> _sessionsFuture;
  int? _payingSessionId;
  int? _loadingAddMoreId;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = TableSessionService.getActiveSessions();
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionsFuture = TableSessionService.getActiveSessions();
    });
  }

  Future<void> _addMoreFood(TableSessionModel session) async {
    setState(() => _loadingAddMoreId = session.id);
    try {
      final restaurant = await RestaurantService.getRestaurantDetail(session.restaurantId);
      if (!mounted) return;

      final cart = Provider.of<CartProvider>(context, listen: false);
      cart.setPendingTableNumber(restaurant.id, restaurant.name, session.tableNumber);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurantId: restaurant.id),
        ),
      ).then((_) => _refresh());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open menu: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAddMoreId = null);
    }
  }

  Future<void> _payNow(TableSessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Pay Rs. ${session.totalAmount.toStringAsFixed(0)} for Table ${session.tableNumber} at ${session.restaurantName}?\n\n'
          'You will pay at the counter — the restaurant will confirm once received.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _payingSessionId = session.id);
    final result = await TableSessionService.paySession(session.id);
    setState(() => _payingSessionId = null);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment requested. Please pay at the counter.')),
      );
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Table')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<TableSessionModel>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final sessions = snapshot.data ?? [];
            if (sessions.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.table_bar, size: 60, color: AppColors.textGrey),
                          SizedBox(height: 12),
                          Text('No open tables right now',
                              style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Scan a table QR code to start a dine-in order.',
                              style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isPaying = _payingSessionId == session.id;
                final isAddingMore = _loadingAddMoreId == session.id;
                final isPaymentPending = session.status == 'PAYMENT_PENDING';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Table ${session.tableNumber}',
                                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isPaymentPending ? Colors.orange : Colors.blue).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isPaymentPending ? 'Payment Pending' : 'Open',
                                style: TextStyle(
                                  color: isPaymentPending ? Colors.orange : Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        ...session.orders.map((order) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order #${order.id} · ${order.status}',
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
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Rs. ${session.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isPaymentPending)
                          const Text(
                            'Waiting for the restaurant to confirm your payment.',
                            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add More Food'),
                                  onPressed: isAddingMore ? null : () => _addMoreFood(session),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: isPaying
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                        onPressed: () => _payNow(session),
                                        child: const Text('Pay Now'),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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