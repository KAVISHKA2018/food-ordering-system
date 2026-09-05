import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';
import '../reservations/make_reservation_picker_screen.dart';

class ReservationsTab extends StatefulWidget {
  const ReservationsTab({super.key});

  @override
  State<ReservationsTab> createState() => ReservationsTabState();
}

class ReservationsTabState extends State<ReservationsTab> {
  late Future<List<ReservationModel>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = ReservationService.getMyReservations();
  }

  Future<void> refresh() async {
    setState(() {
      _reservationsFuture = ReservationService.getMyReservations();
    });
  }

  Future<void> _goMakeReservation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MakeReservationPickerScreen()),
    );
    refresh();
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

  Widget _reservationCard(ReservationModel res) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(res.restaurantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    '${_formatDate(res.reservationDate)} · ${_formatTime(res.reservationTime)}',
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
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
                style: TextStyle(color: _statusColor(res.status), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text('${res.partySize} guest${res.partySize == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const Spacer(),
              Text('Rs. ${res.currentBillTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (res.tableNumber.isNotEmpty) ...[
                  Text('Table ${res.tableNumber}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                  const SizedBox(height: 8),
                ],
                if (res.specialRequests.isNotEmpty) ...[
                  Text('Note: ${res.specialRequests}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  const SizedBox(height: 8),
                ],
                if (res.preOrderItems.isEmpty)
                  const Text('No pre-ordered items for this reservation.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey))
                else ...[
                  const Text('Food Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...res.preOrderItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.displayName, style: const TextStyle(fontSize: 13)),
                                  Text('${item.quantity} × Rs. ${item.unitPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                            Text('Rs. ${item.subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      )),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Rs. ${res.currentBillTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goMakeReservation,
                icon: const Icon(Icons.event_seat),
                label: const Text('Make a Reservation'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
          FutureBuilder<List<ReservationModel>>(
            future: _reservationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load: ${snapshot.error}'),
                );
              }

              final all = snapshot.data ?? [];

              final upcoming = all
                  .where((r) => ['PENDING', 'CONFIRMED'].contains(r.status))
                  .toList()
                ..sort((a, b) => a.reservationDate.compareTo(b.reservationDate));

              final history = all
                  .where((r) => ['COMPLETED', 'CANCELLED', 'NO_SHOW'].contains(r.status))
                  .toList()
                ..sort((a, b) => b.reservationDate.compareTo(a.reservationDate));

              return Column(
                children: [
                  _sectionHeader('Upcoming Reservations'),
                  if (upcoming.isEmpty)
                    _emptyNote('No upcoming reservations.')
                  else
                    ...upcoming.map(_reservationCard),

                  _sectionHeader('Reservation History'),
                  if (history.isEmpty)
                    _emptyNote('No past reservations yet.')
                  else
                    ...history.map(_reservationCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}