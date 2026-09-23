import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../utils/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../orders/my_orders_screen.dart';
import '../orders/payment_details_modal.dart';
import 'about_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My SheIn Connect Profile'),
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          final user = authService.currentUser;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Avatar & Name Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlack,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user != null && user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.fullName ?? 'Shein Shopper',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlack,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: authService.isAdmin ? Colors.purple.shade50 : AppTheme.sheinCoralLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          authService.isAdmin ? 'System Administrator' : 'Malawi Procurement Member',
                          style: TextStyle(
                            color: authService.isAdmin ? Colors.purple.shade700 : AppTheme.sheinCoral,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (authService.isAdmin) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlack,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.admin_panel_settings, size: 18),
                          label: const Text('Admin Control Hub'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // My Orders Tile
                Consumer<SessionService>(
                  builder: (context, sessionSrv, _) {
                    final orderCount = sessionSrv.userOrders.length;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.sheinCoralLight,
                          child: const Icon(Icons.receipt_long_outlined, color: AppTheme.sheinCoral, size: 20),
                        ),
                        title: const Text(
                          'My Procurement Orders',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          orderCount == 0
                              ? 'No orders placed yet'
                              : '$orderCount order${orderCount > 1 ? "s" : ""} recorded in Supabase',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (orderCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.sheinCoral,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$orderCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Details Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.mail_outline,
                        label: 'Email',
                        value: user?.email ?? 'Not set',
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        icon: Icons.phone_iphone_outlined,
                        label: 'Mobile (Malawi)',
                        value: user?.mobile ?? 'Not set',
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        icon: Icons.shield_outlined,
                        label: 'Account Role',
                        value: authService.isAdmin ? 'Administrator (Procurement)' : 'Verified Customer',
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Destination Country',
                        value: 'Malawi (MW)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Accounts & About Section Cards
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blue, size: 20),
                        ),
                        title: const Text(
                          'Payment Details & Bank Info',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'National Bank, Airtel Money, TNM Mpamba',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => PaymentDetailsModal.show(context),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade50,
                          child: const Icon(Icons.info_outline, color: Colors.purple, size: 20),
                        ),
                        title: const Text(
                          'About SheIn Connect',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Dev by Techlink360 • WhatsApp & Facebook',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AboutScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Logout Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Sign Out'),
                  onPressed: () async {
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryBlack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
