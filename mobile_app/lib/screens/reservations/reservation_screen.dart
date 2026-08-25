import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../services/reservation_service.dart';
import 'preorder_selection_screen.dart';

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
  List<SelectedPreOrderItem> _selectedPreOrder = [];
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

  Future<void> _openPreOrderSelection() async {
    final result = await Navigator.push<List<SelectedPreOrderItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => PreOrderSelectionScreen(
          restaurant: widget.restaurant,
          initialSelection: _selectedPreOrder,
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedPreOrder = result);
    }
  }

  double get _preOrderTotal =>
      _selectedPreOrder.fold(0.0, (sum, item) => sum + item.subtotal);

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

    final preOrderItems = _selectedPreOrder
        .map((item) => {
              'menu_item': item.menuItem.id,
              if (item.variant != null) 'variant': item.variant!.id,
              'quantity': item.quantity,
            })
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
          // --- Reservation Details: Date & Time ---
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

          // --- Number of Guests ---
          const SizedBox(height: 24),
          const Text('Number of Guests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

          // --- Add Foods / Pre-Order button ---
          const SizedBox(height: 24),
          const Text('Add Foods / Pre-Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Order ahead so your food is ready when you arrive (optional).',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.restaurant_menu),
            label: Text(_selectedPreOrder.isEmpty ? 'Add Foods / Pre-Order' : 'Edit Pre-Order'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: _openPreOrderSelection,
          ),

          // --- Selected Pre-Ordered Food Items ---
          if (_selectedPreOrder.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Selected Pre-Ordered Food Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  ..._selectedPreOrder.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${item.quantity}x ${item.displayName}',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text('Rs. ${item.subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      )),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pre-Order Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Rs. ${_preOrderTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // --- Special Requests ---
          const SizedBox(height: 24),
          const Text('Special Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _requestsController,
            decoration: const InputDecoration(
              hintText: 'e.g. window seat, birthday celebration',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),

          // --- Request Reservation ---
          const SizedBox(height: 24),
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