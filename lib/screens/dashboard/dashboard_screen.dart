import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/session_service.dart';
import '../../utils/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../orders/my_orders_screen.dart';
import '../orders/payment_details_modal.dart';

/// Customer Dashboard – provides an elegant, modern overview of:
/// • Active Procurement Session status & exchange rate
/// • Local shopping cart metrics and totals
/// • Quick shortcuts to browse Shein and manage cart
class DashboardScreen extends StatelessWidget {
  final VoidCallback? onBrowseShein;
  final VoidCallback? onViewCart;

  const DashboardScreen({
    super.key,
    this.onBrowseShein,
    this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.sheinCoral,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SHEIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Connect',
              style: TextStyle(
                color: AppTheme.primaryBlack,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<SessionService>(
            builder: (context, sessionSrv, _) {
              final count = sessionSrv.userOrders.length;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: AppTheme.sheinCoral,
                  child: const Icon(Icons.receipt_long_outlined, color: AppTheme.primaryBlack),
                ),
                tooltip: 'My Orders',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<AuthService>(
              builder: (context, auth, _) {
                if (!auth.isAdmin) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlack,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Administrator Mode Active',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.sheinCoral,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Admin Hub →', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            // Welcome Greeting
            const Text(
              'Welcome back 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consolidated international shopping from Shein made simple.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 18),

            // Active Procurement Session Hero Card
            Consumer<SessionService>(
              builder: (context, sessionSrv, _) {
                final active = sessionSrv.activeSession;
                final totalSessions = sessionSrv.sessions.length;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1E24), Color(0xFF2C2C36)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: active != null ? AppTheme.successGreen.withValues(alpha: 0.2) : Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active != null ? AppTheme.successGreen : Colors.white30,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: active != null ? AppTheme.successGreen : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  active != null ? active.status.name.toUpperCase() : 'NO ACTIVE SESSION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: active != null ? AppTheme.successGreen : Colors.white70,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$totalSessions Sessions Available',
                            style: const TextStyle(fontSize: 11, color: Colors.white60),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        active?.sessionCode ?? 'Procurement Session',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        active != null
                            ? 'Exchange Rate: 1 USD = ${active.exchangeRate.toStringAsFixed(2)} MWK'
                            : 'Wait for next batch opening to place consolidated orders.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Overview Metric Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 580;
                return isWide
                    ? Row(
                        children: [
                          Expanded(child: _buildCartMetricCard(context)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildProcurementMetricCard(context)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCartMetricCard(context),
                          const SizedBox(height: 12),
                          _buildProcurementMetricCard(context),
                        ],
                      );
              },
            ),

            const SizedBox(height: 24),

            // Quick Actions Header
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sheinCoral,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.travel_explore, size: 20),
                    label: const Text(
                      'Browse Shein',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: onBrowseShein,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlack,
                      side: const BorderSide(color: Color(0xFFD0D5DD), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: const Text(
                      'View Cart',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: onViewCart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Consumer<SessionService>(
              builder: (context, sessionSrv, _) {
                final ordersCount = sessionSrv.userOrders.length;
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlack,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD0D5DD), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Badge(
                      isLabelVisible: ordersCount > 0,
                      label: Text('$ordersCount'),
                      backgroundColor: AppTheme.sheinCoral,
                      child: const Icon(Icons.receipt_long_outlined, size: 20, color: AppTheme.primaryBlack),
                    ),
                    label: Text(
                      ordersCount > 0 ? 'My Procurement Orders ($ordersCount)' : 'My Procurement Orders',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
                  side: BorderSide(color: Colors.blue.shade200, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFF0D47A1)),
                label: const Text(
                  'Payment Accounts & Bank Info (Copy Details)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => PaymentDetailsModal.show(context),
              ),
            ),

            const SizedBox(height: 24),

            // "How It Works" Informative Guide Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppTheme.sheinCoral),
                      SizedBox(width: 8),
                      Text(
                        'How SheIn Connect Works',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlack,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildStepTile(
                    step: '1',
                    title: 'Browse Shein In-App',
                    desc: 'Find any fashion item, dress, or accessories you love.',
                  ),
                  const SizedBox(height: 10),
                  _buildStepTile(
                    step: '2',
                    title: '1-Tap Product Capture',
                    desc: 'Tap "Capture to Cart" to automatically extract price, size, and photo.',
                  ),
                  const SizedBox(height: 10),
                  _buildStepTile(
                    step: '3',
                    title: 'Group Procurement & Delivery',
                    desc: 'Orders are aggregated into sessions for discounted freight shipping.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCartMetricCard(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cart, _) {
        final itemCount = cart.itemCount;
        final totalLocal = cart.totalPriceLocal;
        final totalUsd = cart.subtotalUsd;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.sheinCoralLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.sheinCoral, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlack,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Shopping Cart Total',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                'MWK ${totalLocal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlack,
                ),
              ),
              Text(
                '(\$${totalUsd.toStringAsFixed(2)} USD)',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcurementMetricCard(BuildContext context) {
    return Consumer<SessionService>(
      builder: (context, sessionSrv, _) {
        final active = sessionSrv.activeSession;
        final rate = active?.exchangeRate ?? CartService.usdToMwkRate;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_exchange, color: AppTheme.successGreen, size: 20),
                  ),
                  const Text(
                    'Live Batch',
                    style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Procurement Rate',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                '1 USD = ${rate.toStringAsFixed(0)} MWK',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const Text(
                'Consolidated international rate',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepTile({required String step, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppTheme.primaryBlack,
          child: Text(
            step,
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlack),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
