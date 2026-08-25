import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';

class ReservationHistoryScreen extends StatefulWidget {
  const ReservationHistoryScreen({super.key});

  @override
  State<ReservationHistoryScreen> createState() => _ReservationHistoryScreenState();
}

class _ReservationHistoryScreenState extends State<ReservationHistoryScreen> {
  late Future<List<ReservationModel>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = ReservationService.getMyReservations();
  }

  Future<void> _refresh() async {
    setState(() {
      _reservationsFuture = ReservationService.getMyReservations();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'SEATED':
        return Colors.teal;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'NO_SHOW':
        return Colors.brown;
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

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$hour12:$minute $period';
    } catch (_) {
      return timeStr;
    }
  }

  Widget? _paymentBadge(ReservationModel res) {
    if (res.paymentStatus == 'N/A') return null;

    Color color;
    String label;
    switch (res.paymentStatus) {
      case 'PAID':
        color = Colors.green;
        label = 'Payment Confirmed';
        break;
      case 'PENDING_CONFIRMATION':
        color = Colors.deepOrange;
        label = 'Payment Submitted · Awaiting Confirmation';
        break;
      default:
        color = Colors.grey;
        label = 'Unpaid';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            res.paymentStatus == 'PAID'
                ? Icons.check_circle
                : res.paymentStatus == 'PENDING_CONFIRMATION'
                    ? Icons.hourglass_top
                    : Icons.info_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reservations')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ReservationModel>>(
          future: _reservationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load reservations: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final reservations = snapshot.data ?? [];
            if (reservations.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_seat, size: 60, color: AppColors.textGrey),
                          SizedBox(height: 12),
                          Text('No reservations yet',
                              style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final sorted = List<ReservationModel>.from(reservations)
              ..sort((a, b) => b.reservationDate.compareTo(a.reservationDate));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final res = sorted[index];
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
                              if (res.restaurantName.isNotEmpty)
                                Text(res.restaurantName,
                                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${_formatDate(res.reservationDate)} · ${_formatTime(res.reservationTime)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(res.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(res.status),
                            style: TextStyle(
                              color: _statusColor(res.status),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Text(
                            '${res.partySize} ${res.partySize == 1 ? 'guest' : 'guests'}'
                            '${res.tableNumber.isNotEmpty ? " · Table ${res.tableNumber}" : ""}',
                            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
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
                            if (res.specialRequests.isNotEmpty) ...[
                              Text('Requests: ${res.specialRequests}',
                                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                              const SizedBox(height: 8),
                            ],
                            if (res.preOrderItems.isNotEmpty) ...[
                              const Text('Pre-Order', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              ...res.preOrderItems.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('${item.quantity}x ${item.itemName}')),
                                        Text('Rs. ${item.subtotal.toStringAsFixed(0)}'),
                                      ],
                                    ),
                                  )),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Pre-Order Subtotal'),
                                  Text('Rs. ${res.preOrderTotal.toStringAsFixed(0)}'),
                                ],
                              ),
                            ] else
                              const Text('No pre-order for this reservation.',
                                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                                                        if (res.tableSession != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Current Table Bill',
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Rs. ${res.currentBillTotal.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                            if (_paymentBadge(res) != null) _paymentBadge(res)!,
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