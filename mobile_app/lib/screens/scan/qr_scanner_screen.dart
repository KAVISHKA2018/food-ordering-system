import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../services/restaurant_service.dart';
import '../restaurant/restaurant_detail_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  static final RegExp _qrPattern = RegExp(r'^foodorder://restaurant/(\d+)$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null) return;

    final match = _qrPattern.firstMatch(raw);
    if (match == null) {
      // Not one of our restaurant QR codes — ignore and keep scanning.
      return;
    }

    _handled = true;
    await _controller.stop();

    final restaurantId = int.parse(match.group(1)!);
    if (!mounted) return;

    final tableNumber = await _promptTableNumber();
    if (tableNumber == null || tableNumber.trim().isEmpty) {
      // Cancelled — resume scanning.
      _handled = false;
      await _controller.start();
      return;
    }

    if (!mounted) return;

    try {
      final restaurant = await RestaurantService.getRestaurantDetail(restaurantId);
      if (!mounted) return;

      final cart = Provider.of<CartProvider>(context, listen: false);
      cart.setPendingTableNumber(restaurant.id, restaurant.name, tableNumber.trim());

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurantId: restaurant.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load that restaurant: $e')),
      );
      _handled = false;
      await _controller.start();
    }
  }

  Future<String?> _promptTableNumber() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Table Number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'e.g. 05',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Table QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: const Text(
              'Point your camera at the table QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}