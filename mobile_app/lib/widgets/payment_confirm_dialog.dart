import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Shows the "Confirm Payment" dialog matching the required spec:
/// Restaurant / Order Type / Total / Payment Method, with Cancel and
/// Confirm & Pay buttons. Returns true if confirmed, false/null if
/// cancelled.
Future<bool> showPaymentConfirmDialog({
  required BuildContext context,
  required String restaurantName,
  required String orderTypeLabel,
  required double totalAmount,
  required String paymentMethodLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confirmRow('Restaurant', restaurantName),
          _confirmRow('Order Type', orderTypeLabel),
          _confirmRow('Total Amount', 'Rs. ${totalAmount.toStringAsFixed(0)}'),
          _confirmRow('Payment Method', paymentMethodLabel),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm & Pay'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Widget _confirmRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );
}

/// A small, reusable Cash/Card choice-chip row used on both the Cart
/// screen and the Dine-in Pay Now dialog.
class PaymentMethodSelector extends StatelessWidget {
  final String selected; // 'CASH' or 'CARD'
  final ValueChanged<String> onChanged;

  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _methodChip(
            label: 'Cash',
            icon: Icons.payments_outlined,
            value: 'CASH',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _methodChip(
            label: 'Card',
            icon: Icons.credit_card,
            value: 'CARD',
          ),
        ),
      ],
    );
  }

  Widget _methodChip({required String label, required IconData icon, required String value}) {
    final isSelected = selected == value;
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textGrey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}