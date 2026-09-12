import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/delivery_order_model.dart';
import '../../services/order_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'delivery_detail_screen.dart';

class DeliveriesListScreen extends StatefulWidget {
  const DeliveriesListScreen({super.key});

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen> {
  late Future<List<DeliveryOrderModel>> _deliveriesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _deliveriesFuture = OrderService.getMyDeliveries();
  }

  Future<void> _refresh() async {
    setState(_load);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log Out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _deliveryCard(DeliveryOrderModel order, {required bool isActive}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: (isActive ? AppColors.primary : Colors.green).withValues(alpha: 0.15),
          child: Icon(
            isActive ? Icons.delivery_dining : Icons.check_circle,
            color: isActive ? AppColors.primary : Colors.green,
          ),
        ),
        title: Text('Order #${order.id} — ${order.restaurantName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(order.deliveryAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text('Rs. ${order.totalAmount.toStringAsFixed(0)} · ${_formatDate(order.createdAt)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeliveryDetailScreen(order: order)),
          );
          _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final riderName = auth.user?['first_name']?.toString().isNotEmpty == true
        ? auth.user!['first_name']
        : (auth.user?['username'] ?? 'Rider');

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, $riderName'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _confirmLogout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DeliveryOrderModel>>(
          future: _deliveriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load deliveries: ${snapshot.error}'),
                ),
              ]);
            }

            final all = snapshot.data ?? [];
            final active = all.where((o) => o.status == 'OUT_FOR_DELIVERY').toList();
            final history = all.where((o) => o.status == 'COMPLETED').toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text('Active Deliveries (${active.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No deliveries assigned right now.', style: TextStyle(color: AppColors.textGrey)),
                  )
                else
                  ...active.map((o) => _deliveryCard(o, isActive: true)),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('History', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No completed deliveries yet.', style: TextStyle(color: AppColors.textGrey)),
                  )
                else
                  ...history.take(20).map((o) => _deliveryCard(o, isActive: false)),
              ],
            );
          },
        ),
      ),
    );
  }
}