import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'active_sessions_tab.dart';
import 'reservations_tab.dart';
import 'cart_tab.dart';

class ActivityHubScreen extends StatefulWidget {
  final int initialTabIndex;
  const ActivityHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ActivityHubScreen> createState() => _ActivityHubScreenState();
}

class _ActivityHubScreenState extends State<ActivityHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Your Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: CartTab()),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Reservations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ActiveSessionsTab(cart: cart),
          const ReservationsTab(),
        ],
      ),
    );
  }
}