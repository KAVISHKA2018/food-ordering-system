import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/cart_provider.dart';

/// A draggable floating cart bubble (AssistiveTouch-style) that the
/// customer can reposition anywhere within its parent area. Only visible
/// when the cart has at least one item across any restaurant. Tapping it
/// triggers [onTap] — typically opening a cart summary sheet.
///
/// [areaSize] must be the actual size of the Stack this button lives in
/// (e.g. from a LayoutBuilder around the Scaffold's body) — NOT the full
/// screen size, since the body is shorter than the screen once the AppBar
/// and TabBar are accounted for.
class FloatingCartButton extends StatefulWidget {
  final VoidCallback onTap;
  final Size areaSize;
  const FloatingCartButton({super.key, required this.onTap, required this.areaSize});

  @override
  State<FloatingCartButton> createState() => _FloatingCartButtonState();
}

class _FloatingCartButtonState extends State<FloatingCartButton> {
  Offset? _position;
  static const double _size = 58;
  static const double _bottomMargin = 24;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    if (!cart.hasAnyItems) return const SizedBox.shrink();

    final width = widget.areaSize.width;
    final height = widget.areaSize.height;

    _position ??= Offset(width - _size - 18, height - _size - _bottomMargin);

    final totalItems = cart.restaurantCarts.fold<int>(0, (sum, c) => sum + c.itemCount);

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final newX = (_position!.dx + details.delta.dx).clamp(0.0, width - _size);
            final newY = (_position!.dy + details.delta.dy).clamp(0.0, height - _size);
            _position = Offset(newX, newY);
          });
        },
        onTap: widget.onTap,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(Icons.shopping_cart, color: Colors.white, size: 26),
              ),
              if (totalItems > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      totalItems > 99 ? '99+' : '$totalItems',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}