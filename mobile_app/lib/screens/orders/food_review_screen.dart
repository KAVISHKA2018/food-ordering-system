import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/order_model.dart';
import '../../services/food_review_service.dart';

class FoodReviewScreen extends StatefulWidget {
  final OrderModel order;
  const FoodReviewScreen({super.key, required this.order});

  @override
  State<FoodReviewScreen> createState() => _FoodReviewScreenState();
}

class _FoodReviewScreenState extends State<FoodReviewScreen> {
  late Map<int, int> _ratings; // orderItemId -> star rating (0 = not rated)
  late Map<int, TextEditingController> _comments;
  late Map<int, bool> _submitted; // orderItemId -> already saved this session
  bool _submitting = false;

  List<OrderItemModel> get _reviewableItems =>
      widget.order.items.where((item) => !item.hasFoodReview && item.id != null).toList();

  @override
  void initState() {
    super.initState();
    _ratings = {for (final item in _reviewableItems) item.id!: 0};
    _comments = {for (final item in _reviewableItems) item.id!: TextEditingController()};
    _submitted = {for (final item in _reviewableItems) item.id!: false};
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitAll() async {
    final toSubmit = _ratings.entries.where((e) => e.value > 0 && !_submitted[e.key]!).toList();
    if (toSubmit.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _submitting = true);

    int failCount = 0;
    for (final entry in toSubmit) {
      final result = await FoodReviewService.submitReview(
        orderItemId: entry.key,
        rating: entry.value,
        comment: _comments[entry.key]!.text.trim(),
      );
      if (result['success']) {
        _submitted[entry.key] = true;
      } else {
        failCount++;
      }
    }

    setState(() => _submitting = false);

    if (!mounted) return;

    if (failCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failCount item review(s) failed to submit.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for rating your food!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _reviewableItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Food'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: AppColors.textGrey)),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No items left to rate for this order.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'How was each item? Tap the stars to rate — you can skip items you don\'t want to rate.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...items.map((item) {
                  final rating = _ratings[item.id!]!;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (index) {
                              final starValue = index + 1;
                              return IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  starValue <= rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                                onPressed: () => setState(() => _ratings[item.id!] = starValue),
                              );
                            }),
                          ),
                          if (rating > 0) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _comments[item.id!],
                              decoration: const InputDecoration(
                                hintText: 'Add a comment (optional)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _submitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitAll,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Submit Reviews', style: TextStyle(fontSize: 16)),
                      ),
              ),
            ),
    );
  }
}