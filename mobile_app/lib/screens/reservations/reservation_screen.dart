import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../services/reservation_service.dart';

class ReservationScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const ReservationScreen({super.key, required this.restaurant});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _partySize = 2;
  final _requestsController = TextEditingController();
  final Map<int, int> _preOrderQuantities = {}; // menuItemId -> quantity
  bool _submitting = false;

  @override
  void dispose() {
    _requestsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  double get _preOrderTotal {
    double total = 0;
    for (final category in widget.restaurant.categories) {
      for (final item in category.menuItems) {
        final qty = _preOrderQuantities[item.id] ?? 0;
        total += item.price * qty;
      }
    }
    return total;
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    setState(() => _submitting = true);

    final dateStr =
        '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

    final preOrderItems = _preOrderQuantities.entries
        .where((e) => e.value > 0)
        .map((e) => {'menu_item': e.key, 'quantity': e.value})
        .toList();

    final result = await ReservationService.createReservation(
      restaurantId: widget.restaurant.id,
      reservationDate: dateStr,
      reservationTime: timeStr,
      partySize: _partySize,
      preOrderItems: preOrderItems,
      specialRequests: _requestsController.text.trim(),
    );

    setState(() => _submitting = false);

    if (result['success'] && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Reservation Requested'),
          content: Text(
              'Your table for $_partySize at ${widget.restaurant.name} on $dateStr has been requested. You\'ll be notified once confirmed.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // back to restaurant detail
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      final error = result['error'];
      String message = 'Failed to create reservation';
      if (error is Map) {
        message = error.values.first.toString();
      } else if (error is List) {
        message = error.first.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reserve · ${widget.restaurant.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_selectedDate == null
                      ? 'Pick Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_selectedTime == null
                      ? 'Pick Time'
                      : _selectedTime!.format(context)),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Party Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                onPressed: _partySize > 1
                    ? () => setState(() => _partySize -= 1)
                    : null,
              ),
              Text('$_partySize ${_partySize == 1 ? 'guest' : 'guests'}',
                  style: const TextStyle(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                onPressed: () => setState(() => _partySize += 1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Special Requests (optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _requestsController,
            decoration: const InputDecoration(
              hintText: 'e.g. window seat, birthday celebration',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          const Text('Pre-Order Food (optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Order ahead so your food is ready when you arrive.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (widget.restaurant.categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No menu items available for pre-order.'),
            )
          else
            ...widget.restaurant.categories.map((category) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(category.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ...category.menuItems.where((item) => item.isAvailable).map((item) {
                    final qty = _preOrderQuantities[item.id] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text('Rs. ${item.price.toStringAsFixed(0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 0
                                ? () => setState(() => _preOrderQuantities[item.id] = qty - 1)
                                : null,
                          ),
                          Text('$qty'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                setState(() => _preOrderQuantities[item.id] = qty + 1),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }),
          const SizedBox(height: 16),
          if (_preOrderTotal > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pre-Order Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Rs. ${_preOrderTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          _submitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Text('Request Reservation', style: TextStyle(fontSize: 16)),
                ),
        ],
      ),
    );
  }
}