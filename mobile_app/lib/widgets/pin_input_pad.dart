import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A reusable PIN/OTP entry widget: dot progress indicator + on-screen
/// numeric keypad. Used for OTP verification, PIN setup, and PIN login,
/// so the whole app has one consistent, themed input experience instead
/// of raw text fields.
class PinInputPad extends StatefulWidget {
  final int length;
  final void Function(String code) onCompleted;
  final String? errorText;

  const PinInputPad({
    super.key,
    required this.length,
    required this.onCompleted,
    this.errorText,
  });

  @override
  State<PinInputPad> createState() => PinInputPadState();
}

class PinInputPadState extends State<PinInputPad> {
  String _value = '';

  void clear() {
    setState(() => _value = '');
  }

  void _onDigit(String digit) {
    if (_value.length >= widget.length) return;
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      widget.onCompleted(_value);
    }
  }

  void _onBackspace() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            final filled = index < _value.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.primary : AppColors.textGrey,
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 10),
          Text(widget.errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 28),
        _buildKeypad(),
      ],
    );
  }

  Widget _buildKeypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        if (key == 'back') {
          return IconButton(
            onPressed: _onBackspace,
            icon: const Icon(Icons.backspace_outlined, color: AppColors.textDark),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => _onDigit(key),
          child: Center(
            child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
        );
      }).toList(),
    );
  }
}