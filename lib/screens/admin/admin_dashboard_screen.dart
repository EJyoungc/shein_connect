import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/payment_detail_model.dart';
import '../../models/procurement_session_model.dart';
import '../../models/session_order_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../utils/app_theme.dart';
import '../browser/browser_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await Future.wait([
      sessionService.loadSessions(),
      sessionService.loadAllOrders(),
      sessionService.loadCustomers(),
      sessionService.loadPaymentDetails(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final sessionService = Provider.of<SessionService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlack,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Control Hub',
              style: TextStyle(
                color: AppTheme.primaryBlack,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryBlack),
            tooltip: 'Sync Supabase Data',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing with Supabase database...'),
                  duration: Duration(seconds: 1),
                ),
              );
              await _refreshAllData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Log Out',
            onPressed: () => _confirmLogout(context, authService),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.sheinCoral,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.sheinCoral,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: 'Overview'),
            Tab(
              icon: const Icon(Icons.layers_outlined, size: 20),
              text: 'Sessions (${sessionService.sessions.length})',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: sessionService.pendingApprovalsCount > 0,
                label: Text('${sessionService.pendingApprovalsCount}'),
                child: const Icon(Icons.receipt_long_outlined, size: 20),
              ),
              text: 'Customer Orders',
            ),
            Tab(
              icon: const Icon(Icons.people_outline, size: 20),
              text: 'Users (${sessionService.customers.length})',
            ),
            Tab(
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
              text: 'Payment Accounts (${sessionService.paymentDetails.length})',
            ),
          ],
        ),
      ),
      body: sessionService.isAdminLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.sheinCoral))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(sessionService),
                _buildSessionsTab(sessionService),
                _buildOrdersTab(sessionService),
                _buildCustomersTab(sessionService),
                _buildPaymentDetailsTab(sessionService),
              ],
            ),
      floatingActionButton: _tabController.index == 4
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryBlack,
              icon: const Icon(Icons.add_card, color: Colors.white),
              label: const Text('Add Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddEditPaymentDetailModal(context, sessionService),
            )
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryBlack,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showCreateSessionModal(context, sessionService),
            ),
    );
  }

  // ===========================================================================
  // TAB 1: OVERVIEW & KPIS
  // ===========================================================================
  Widget _buildOverviewTab(SessionService sessionService) {
    final active = sessionService.activeSession;
    final totalOrders = sessionService.totalOrdersCount;
    final revenue = sessionService.totalRevenueMwk;
    final pending = sessionService.pendingApprovalsCount;

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live Supabase Database Connected (Direct Mode)',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top KPI Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Confirmed Revenue',
                    value: 'MWK ${_currencyFormat.format(revenue)}',
                    icon: Icons.payments_outlined,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pending Verifications',
                    value: '$pending orders',
                    icon: Icons.pending_actions,
                    color: pending > 0 ? AppTheme.sheinCoral : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Orders Placed',
                    value: '$totalOrders',
                    icon: Icons.shopping_cart_checkout,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Active Batch Sessions',
                    value: '${sessionService.sessions.length}',
                    icon: Icons.event_repeat,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Active Batch Hero Card
            const Text(
              'Current Procurement Batch',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlack),
            ),
            const SizedBox(height: 10),
            if (active != null)
              _buildSessionCard(context, sessionService, active, isHighlight: true)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No Active Procurement Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create a procurement batch session to allow customers to submit Shein orders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlack,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Initial Session'),
                      onPressed: () => _showCreateSessionModal(context, sessionService),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            // Quick Administrative Shortcuts
            const Text(
              'Administrative Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlack),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    icon: const Icon(Icons.travel_explore, color: AppTheme.sheinCoral),
                    label: const Text('Open Shein Browser', style: TextStyle(color: AppTheme.primaryBlack)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const Scaffold(body: BrowserScreen())),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    icon: const Icon(Icons.shopping_basket_outlined, color: Colors.teal),
                    label: const Text('Consolidated Batch', style: TextStyle(color: AppTheme.primaryBlack)),
                    onPressed: () {
                      if (active != null) {
                        _showConsolidatedBatchSheet(context, sessionService, active);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please create or select a session first.')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SESSIONS MANAGEMENT
  // ===========================================================================
  Widget _buildSessionsTab(SessionService sessionService) {
    final sessions = sessionService.sessions;

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 54, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No sessions recorded in Supabase.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showCreateSessionModal(context, sessionService),
                    child: const Text('Create New Session'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sessions.length + 1,
              itemBuilder: (context, index) {
                if (index == sessions.length) {
                  return const SizedBox(height: 70);
                }
                final session = sessions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildSessionCard(context, sessionService, session),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // TAB 3: CUSTOMER ORDERS & PAYMENTS APPROVAL
  // ===========================================================================
  Widget _buildOrdersTab(SessionService sessionService) {
    final orders = sessionService.allOrders;

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: orders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 54, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No customer orders received yet.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Orders submitted by customers via Shein Connect will appear here with live payment receipts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length + 1,
              itemBuilder: (context, index) {
                if (index == orders.length) return const SizedBox(height: 70);
                final order = orders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildOrderCard(context, sessionService, order),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // TAB 4: USERS / CUSTOMERS LIST
  // ===========================================================================
  Widget _buildCustomersTab(SessionService sessionService) {
    final customers = sessionService.customers;

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: customers.isEmpty
          ? const Center(child: Text('No registered profiles in Supabase.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: customers.length + 1,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == customers.length) return const SizedBox(height: 70);
                final user = customers[index];
                final role = user['role'] as String? ?? 'customer';
                final isAdmin = role == 'admin';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? AppTheme.primaryBlack : AppTheme.sheinCoralLight,
                      child: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: isAdmin ? Colors.white : AppTheme.sheinCoral,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      user['full_name'] as String? ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${user["phone_number"] ?? "No phone"} • ${user["email"] ?? "No email"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.purple.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAdmin ? Colors.purple : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // CARD BUILDERS & MODALS
  // ===========================================================================

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlack)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    SessionService sessionService,
    ProcurementSessionModel session, {
    bool isHighlight = false,
  }) {
    Color statusColor;
    switch (session.status) {
      case SessionStatus.open:
        statusColor = Colors.green;
        break;
      case SessionStatus.locked:
        statusColor = Colors.orange;
        break;
      case SessionStatus.purchased:
        statusColor = Colors.blue;
        break;
      case SessionStatus.inTransit:
        statusColor = Colors.purple;
        break;
      case SessionStatus.readyForPickup:
        statusColor = Colors.teal;
        break;
      case SessionStatus.closed:
        statusColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? AppTheme.sheinCoral : Colors.grey.shade200, width: isHighlight ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers, size: 20, color: AppTheme.primaryBlack),
                  const SizedBox(width: 8),
                  Text(
                    session.sessionCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status.displayName,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '1 USD = MWK ${_currencyFormat.format(session.exchangeRate)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              Text(
                'Target: \$${_currencyFormat.format(session.targetAmountUsd)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status Changer Dropdown
              DropdownButton<SessionStatus>(
                value: session.status,
                underline: const SizedBox(),
                isDense: true,
                items: SessionStatus.values.map((st) {
                  return DropdownMenuItem(
                    value: st,
                    child: Text(st.displayName, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (newStatus) async {
                  if (newStatus != null && newStatus != session.status) {
                    final res = await sessionService.updateSessionStatus(
                      sessionId: session.id,
                      newStatus: newStatus,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                    }
                  }
                },
              ),

              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlack, size: 20),
                    tooltip: 'Edit Session Details',
                    onPressed: () => _showEditSessionModal(context, sessionService, session),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check, color: AppTheme.primaryBlack, size: 20),
                    tooltip: 'Consolidated Items to Buy',
                    onPressed: () => _showConsolidatedBatchSheet(context, sessionService, session),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Session',
                    onPressed: () => _confirmDeleteSession(context, sessionService, session),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pendingPayment:
        return Colors.orange;
      case PaymentStatus.verifying:
        return Colors.blue;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.rejected:
        return Colors.red;
    }
  }

  Widget _buildOrderCard(BuildContext context, SessionService sessionService, SessionOrderModel order) {
    final statusColor = _getPaymentStatusColor(order.paymentStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.receipt, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.customerName ?? 'Customer #${order.userId.substring(0, 6)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (order.sessionCode != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  order.sessionCode!,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
          ],
        ),
        subtitle: Text(
          'MWK ${_currencyFormat.format(order.totalCostLocal)} • ${order.items.length} items',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            order.paymentStatus.displayName,
            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer details
                Row(
                  children: [
                    if (order.customerPhone != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(order.customerPhone!, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    if (order.customerEmail != null)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.email, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                order.customerEmail!,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ordered Items Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ordered Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${order.items.length} product(s)', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                ...order.items.map((item) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        if (item.imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              item.imageUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (c, o, s) => const Icon(Icons.image, size: 44),
                            ),
                          )
                        else
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.image_not_supported, size: 22, color: Colors.grey),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${item.selectedOption ?? "No option"} • Qty: ${item.quantity}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              Text(
                                '\$${(item.priceUsd * item.quantity).toStringAsFixed(2)} (\$${item.priceUsd.toStringAsFixed(2)} ea)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ],
                          ),
                        ),
                        // Link leading to item on Shein in browser
                        IconButton(
                          icon: const Icon(Icons.open_in_browser, color: AppTheme.sheinCoral),
                          tooltip: 'Open item on SheIn',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  body: BrowserScreen(
                                    initialUrl: item.productUrl.isNotEmpty ? item.productUrl : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Proof of Payment Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                        ? Colors.blue.shade50.withValues(alpha: 0.5)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                          ? Colors.blue.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                            ? Icons.receipt_long
                            : Icons.receipt_outlined,
                        size: 20,
                        color: (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                            ? Colors.blue.shade700
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                              ? 'Payment receipt attached'
                              : 'No payment proof uploaded yet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                                ? Colors.blue.shade900
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      if (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.remove_red_eye, size: 14),
                          label: const Text('View Proof', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showProofPreviewDialog(context, order),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 24),

                // State Changer & Move Session Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Move Session Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.primaryBlack,
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                      label: const Text('Move Session', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showMoveOrderSessionModal(context, sessionService, order),
                    ),

                    // Order State Selector Dropdown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('State: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.white,
                          ),
                          child: DropdownButton<PaymentStatus>(
                            value: order.paymentStatus,
                            underline: const SizedBox(),
                            isDense: true,
                            items: PaymentStatus.values.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getPaymentStatusColor(status),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newStatus) async {
                              if (newStatus != null && newStatus != order.paymentStatus) {
                                final res = await sessionService.updateOrderPaymentStatus(
                                  orderId: order.id,
                                  status: newStatus,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODALS & DIALOGS
  // ===========================================================================

  void _showCreateSessionModal(BuildContext context, SessionService sessionService) {
    final codeCtrl = TextEditingController(text: 'SHEIN-MW-${DateFormat("MMM").format(DateTime.now()).toUpperCase()}-01');
    final rateCtrl = TextEditingController(text: '1750');
    final targetCtrl = TextEditingController(text: '1500');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create Procurement Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Directly opens a live purchasing batch for customers.', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Session Code (Batch Identifier)', hintText: 'e.g. SHEIN-MW-2026-02'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Exchange Rate (MWK per 1 USD)', hintText: '1750'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target Batch Goal (USD)', hintText: '1500'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final code = codeCtrl.text.trim();
                  final rate = double.tryParse(rateCtrl.text.trim()) ?? 1750.0;
                  final target = double.tryParse(targetCtrl.text.trim()) ?? 1000.0;

                  final res = await sessionService.createSession(
                    sessionCode: code,
                    exchangeRate: rate,
                    targetAmountUsd: target,
                  );

                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                  }
                },
                child: const Text('Create Batch Session in Supabase'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditSessionModal(
    BuildContext context,
    SessionService sessionService,
    ProcurementSessionModel session,
  ) {
    final codeCtrl = TextEditingController(text: session.sessionCode);
    final rateCtrl = TextEditingController(
      text: session.exchangeRate % 1 == 0
          ? session.exchangeRate.toInt().toString()
          : session.exchangeRate.toString(),
    );
    final targetCtrl = TextEditingController(
      text: session.targetAmountUsd % 1 == 0
          ? session.targetAmountUsd.toInt().toString()
          : session.targetAmountUsd.toString(),
    );
    SessionStatus selectedStatus = session.status;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Procurement Session',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Update session parameters, exchange rate, and batch status directly in Supabase.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Session Code (Batch Identifier)',
                        hintText: 'e.g. SHEIN-MW-2026-02',
                        prefixIcon: Icon(Icons.tag, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Exchange Rate (MWK per 1 USD)',
                        hintText: '1750',
                        prefixIcon: Icon(Icons.currency_exchange, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Batch Goal (USD)',
                        hintText: '1500',
                        prefixIcon: Icon(Icons.monetization_on_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SessionStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Session Lifecycle Status',
                        prefixIcon: Icon(Icons.timelapse, size: 20),
                      ),
                      items: SessionStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.displayName),
                        );
                      }).toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          setModalState(() {
                            selectedStatus = newStatus;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlack,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final code = codeCtrl.text.trim();
                              final rate = double.tryParse(rateCtrl.text.trim());
                              final target = double.tryParse(targetCtrl.text.trim());

                              if (code.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a session code.')),
                                );
                                return;
                              }
                              if (rate == null || rate <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid exchange rate.')),
                                );
                                return;
                              }
                              if (target == null || target < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid target amount.')),
                                );
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                              });

                              final res = await sessionService.updateSession(
                                sessionId: session.id,
                                sessionCode: code,
                                exchangeRate: rate,
                                targetAmountUsd: target,
                                status: selectedStatus,
                              );

                              if (modalContext.mounted) {
                                Navigator.of(modalContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.message),
                                    backgroundColor: res.success ? AppTheme.successGreen : Colors.red,
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Changes in Supabase',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showConsolidatedBatchSheet(BuildContext context, SessionService sessionService, ProcurementSessionModel session) {
    final consolidated = sessionService.getConsolidatedItemsForSession(session.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bulk Buying List (${session.sessionCode})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              Text(
                'Consolidates verified customer items for single Shein order checkout.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Divider(height: 20),
              if (consolidated.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No paid or verified orders in this batch yet.', style: TextStyle(color: Colors.black54)),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: consolidated.length,
                    separatorBuilder: (c, i) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final item = consolidated[i];
                      return Row(
                        children: [
                          if (item.imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(item.imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image, size: 44)),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Options: ${item.selectedOption ?? "None"}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                Text('Total Qty: ${item.quantity} units • Total: \$${item.totalUsd.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_browser, color: AppTheme.sheinCoral),
                            tooltip: 'Procure on Shein',
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const Scaffold(body: BrowserScreen())),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteSession(BuildContext context, SessionService sessionService, ProcurementSessionModel session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text('Are you sure you want to delete session "${session.sessionCode}" from Supabase?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final res = await sessionService.deleteSession(session.id);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
            },
          ),
        ],
      ),
    );
  }

  void _showProofPreviewDialog(BuildContext context, SessionOrderModel order) {
    final url = order.proofOfPaymentUrl;
    if (url == null || url.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Proof of Payment',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${order.customerName ?? "Customer"} • MWK ${_currencyFormat.format(order.totalCostLocal)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Failed to load image preview'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 16),
                        label: const Text('Open External', style: TextStyle(fontSize: 12)),
                        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlack,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoveOrderSessionModal(BuildContext context, SessionService sessionService, SessionOrderModel order) {
    final sessions = sessionService.sessions;
    String? selectedSessionId = order.sessionId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Move Order to Another Session',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(modalContext).pop()),
                    ],
                  ),
                  Text(
                    'Customer: ${order.customerName ?? "Customer"} • Total: MWK ${_currencyFormat.format(order.totalCostLocal)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Target Procurement Batch:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No procurement sessions available.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isCurrent = session.id == order.sessionId;
                          final isSelected = session.id == selectedSessionId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? AppTheme.sheinCoral : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: isSelected ? AppTheme.sheinCoralLight.withValues(alpha: 0.2) : Colors.white,
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? AppTheme.sheinCoral : Colors.grey,
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  Text(session.sessionCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                'Status: ${session.status.displayName} • Rate: MWK ${_currencyFormat.format(session.exchangeRate)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                setModalState(() {
                                  selectedSessionId = session.id;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlack,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: selectedSessionId == null || selectedSessionId == order.sessionId
                        ? null
                        : () async {
                            final res = await sessionService.moveOrderToSession(
                              orderId: order.id,
                              targetSessionId: selectedSessionId!,
                            );
                            if (modalContext.mounted) {
                              Navigator.of(modalContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success ? AppTheme.successGreen : Colors.red,
                                ),
                              );
                            }
                          },
                    child: const Text('Confirm Move Order', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 5: PAYMENT ACCOUNTS (Admin can Add, Edit, Remove Bank / Airtel / Mpamba)
  // ===========================================================================
  Widget _buildPaymentDetailsTab(SessionService sessionService) {
    final paymentAccounts = sessionService.paymentDetails;

    return RefreshIndicator(
      color: AppTheme.sheinCoral,
      onRefresh: sessionService.loadPaymentDetails,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Customer Payment Destinations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Accounts listed here are shown to customers on checkout and in the Payment Details modal. Customers can tap to copy account numbers.',
                        style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header with Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configured Accounts (${paymentAccounts.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Account', style: TextStyle(fontSize: 12)),
                onPressed: () => _showAddEditPaymentDetailModal(context, sessionService),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (paymentAccounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No payment accounts created yet.',
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add Bank, Airtel Money, or TNM Mpamba accounts for your customers.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...paymentAccounts.map((account) => _buildAdminPaymentAccountCard(context, sessionService, account)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAdminPaymentAccountCard(
    BuildContext context,
    SessionService sessionService,
    PaymentDetailModel account,
  ) {
    Color badgeColor;
    IconData typeIcon;

    switch (account.type) {
      case PaymentDetailType.bank:
        badgeColor = const Color(0xFF0D47A1);
        typeIcon = Icons.account_balance;
        break;
      case PaymentDetailType.airtelMoney:
        badgeColor = const Color(0xFFD32F2F);
        typeIcon = Icons.phone_android;
        break;
      case PaymentDetailType.mpamba:
        badgeColor = const Color(0xFF2E7D32);
        typeIcon = Icons.account_balance_wallet;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: account.isActive ? Colors.grey.shade200 : Colors.red.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlack,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: account.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: account.isActive ? Colors.green.shade300 : Colors.grey.shade400,
                              ),
                            ),
                            child: Text(
                              account.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: account.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (account.branchName != null && account.branchName!.isNotEmpty)
                        Text(
                          'Branch: ${account.branchName}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                // Edit & Delete actions
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueAccent),
                  tooltip: 'Edit Account',
                  onPressed: () => _showAddEditPaymentDetailModal(context, sessionService, existing: account),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Remove Account',
                  onPressed: () => _confirmDeletePaymentDetail(context, sessionService, account),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Owner Name',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.accountName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      account.type == PaymentDetailType.bank ? 'Account Number' : 'Mobile Number',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.accountNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.sheinCoral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (account.instructions != null && account.instructions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Instructions: ${account.instructions}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddEditPaymentDetailModal(
    BuildContext context,
    SessionService sessionService, {
    PaymentDetailModel? existing,
  }) {
    final isEdit = existing != null;
    PaymentDetailType selectedType = existing?.type ?? PaymentDetailType.bank;
    final accountNameCtrl = TextEditingController(text: existing?.accountName ?? '');
    final accountNumberCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final bankNameCtrl = TextEditingController(text: existing?.bankName ?? '');
    final branchNameCtrl = TextEditingController(text: existing?.branchName ?? '');
    final instructionsCtrl = TextEditingController(text: existing?.instructions ?? '');
    bool isActive = existing?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Payment Account' : 'Add Payment Account',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Account Type Selector
                    const Text('Account Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PaymentDetailType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: PaymentDetailType.bank,
                          child: Text('Bank Transfer (National Bank, Standard, FDH, etc.)'),
                        ),
                        DropdownMenuItem(
                          value: PaymentDetailType.airtelMoney,
                          child: Text('Airtel Money (Malawi)'),
                        ),
                        DropdownMenuItem(
                          value: PaymentDetailType.mpamba,
                          child: Text('TNM Mpamba (Malawi)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Bank Name (only if bank)
                    if (selectedType == PaymentDetailType.bank) ...[
                      const Text('Bank Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bankNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. National Bank of Malawi / Standard Bank',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Branch Name (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: branchNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Victoria Avenue Branch, Blantyre',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Account Owner Name
                    const Text('Name of Owner of the Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. SheIn Connect Procurement MW',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Account / Phone Number
                    Text(
                      selectedType == PaymentDetailType.bank ? 'Account Number' : 'Mobile Number',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountNumberCtrl,
                      decoration: InputDecoration(
                        hintText: selectedType == PaymentDetailType.bank ? 'e.g. 1006543210' : 'e.g. 0995936887',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Instructions / Reference notes
                    const Text('Special Instructions / Notes (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: instructionsCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Use your Session Order ID as payment reference.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Active Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show Account to Customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Deactivating will hide this account from customer views', style: TextStyle(fontSize: 11)),
                      value: isActive,
                      activeThumbColor: AppTheme.sheinCoral,
                      onChanged: (val) {
                        setModalState(() {
                          isActive = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlack,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (accountNameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter the account owner name.')),
                          );
                          return;
                        }
                        if (accountNumberCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter the account or mobile number.')),
                          );
                          return;
                        }

                        bool ok;
                        if (isEdit) {
                          ok = await sessionService.updatePaymentDetail(
                            id: existing.id,
                            type: selectedType,
                            accountName: accountNameCtrl.text,
                            accountNumber: accountNumberCtrl.text,
                            bankName: bankNameCtrl.text,
                            branchName: branchNameCtrl.text,
                            instructions: instructionsCtrl.text,
                            isActive: isActive,
                          );
                        } else {
                          ok = await sessionService.addPaymentDetail(
                            type: selectedType,
                            accountName: accountNameCtrl.text,
                            accountNumber: accountNumberCtrl.text,
                            bankName: bankNameCtrl.text,
                            branchName: branchNameCtrl.text,
                            instructions: instructionsCtrl.text,
                            isActive: isActive,
                          );
                        }

                        if (modalCtx.mounted) {
                          Navigator.of(modalCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? (isEdit ? 'Payment account updated!' : 'Payment account added!')
                                  : 'Operation failed. Please check your connection.'),
                              backgroundColor: ok ? AppTheme.successGreen : Colors.red,
                            ),
                          );
                        }
                      },
                      child: Text(
                        isEdit ? 'Save Changes' : 'Create Payment Account',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePaymentDetail(
    BuildContext context,
    SessionService sessionService,
    PaymentDetailModel account,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Payment Account?'),
        content: Text('Are you sure you want to remove ${account.title} (${account.accountNumber})? Customers will no longer see this account.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await sessionService.deletePaymentDetail(account.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Account removed.' : 'Failed to delete account.'),
                    backgroundColor: ok ? AppTheme.successGreen : Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to end your administrator session?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Log Out'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await authService.logout();
            },
          ),
        ],
      ),
    );
  }
}
