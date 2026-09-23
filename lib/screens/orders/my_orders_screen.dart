import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/session_order_model.dart';
import '../../services/session_service.dart';
import '../../utils/app_theme.dart';
import '../browser/browser_screen.dart';
import 'payment_details_modal.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final ImagePicker _picker = ImagePicker();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }


  Future<void> _loadOrders() async {
    setState(() => _isRefreshing = true);
    final sessionService = Provider.of<SessionService>(context, listen: false);
    await sessionService.loadUserOrders();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _confirmRemoveOrder(
    SessionService sessionService,
    SessionOrderModel order,
  ) async {
    if (!order.canRemove) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot cancel order: Session batch is ${order.sessionStatus?.displayName ?? "Locked"}.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Remove Order?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove this order from batch "${order.sessionCode ?? 'Procurement'}"?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'This will cancel the order and delete all ${order.items.length} items from this procurement batch.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Remove Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Removing order from Supabase...'),
        duration: Duration(seconds: 1),
      ),
    );

    final res = await sessionService.deleteUserOrder(order.id);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppTheme.successGreen : Colors.red,
      ),
    );
  }

  void _showProofOfPaymentModal(
    BuildContext context,
    SessionService sessionService,
    SessionOrderModel order,
  ) {
    Uint8List? selectedImageBytes;
    String? selectedExtension;
    bool isUploading = false;
    final urlCtrl = TextEditingController(text: order.proofOfPaymentUrl ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
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
                        Row(
                          children: const [
                            Icon(Icons.receipt_long, color: AppTheme.sheinCoral),
                            SizedBox(width: 8),
                            Text(
                              'Proof of Payment',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Batch: ${order.sessionCode ?? "Procurement"} • Amount: MWK ${_currencyFormat.format(order.totalCostLocal)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.sheinCoral),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your transfer receipt (Airtel Money, TNM Mpamba, or Bank slip).',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => PaymentDetailsModal.show(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF0D47A1)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Need Bank / Airtel / Mpamba account details? View & Copy',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0D47A1)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // Existing uploaded proof display if available
                    if (order.proofOfPaymentUrl != null &&
                        order.proofOfPaymentUrl!.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Uploaded Receipt:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          width: double.infinity,
                          color: Colors.grey.shade100,
                          child: Image.network(
                            order.proofOfPaymentUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (c, o, s) => Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                  const SizedBox(height: 6),
                                  Text(
                                    order.proofOfPaymentUrl!,
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'To change or replace this receipt, choose a new photo below and submit.',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Newly selected image preview
                    if (selectedImageBytes != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'New Replacement Selected:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: const Text('Ready to upload', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              width: double.infinity,
                              color: Colors.black12,
                              child: Image.memory(
                                selectedImageBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                            onPressed: () {
                              setModalState(() {
                                selectedImageBytes = null;
                                selectedExtension = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Image picker action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFD0D5DD)),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 18, color: AppTheme.primaryBlack),
                            label: Text(
                              (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                                  ? 'Change Photo'
                                  : 'Choose Photo',
                              style: const TextStyle(color: AppTheme.primaryBlack, fontSize: 13),
                            ),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      final picked = await _picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 85,
                                      );
                                      if (picked != null) {
                                        final bytes = await picked.readAsBytes();
                                        final ext = picked.name.contains('.')
                                            ? picked.name.split('.').last
                                            : 'jpg';
                                        setModalState(() {
                                          selectedImageBytes = bytes;
                                          selectedExtension = ext;
                                        });
                                      }
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Error picking image: $e')),
                                      );
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFD0D5DD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppTheme.primaryBlack),
                            label: const Text('Take Picture', style: TextStyle(color: AppTheme.primaryBlack, fontSize: 13)),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      final picked = await _picker.pickImage(
                                        source: ImageSource.camera,
                                        imageQuality: 85,
                                      );
                                      if (picked != null) {
                                        final bytes = await picked.readAsBytes();
                                        final ext = picked.name.contains('.')
                                            ? picked.name.split('.').last
                                            : 'jpg';
                                        setModalState(() {
                                          selectedImageBytes = bytes;
                                          selectedExtension = ext;
                                        });
                                      }
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Error using camera: $e')),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Direct URL input fallback
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Or enter receipt link directly',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      children: [
                        TextField(
                          controller: urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Receipt Image URL',
                            hintText: 'https://example.com/receipt.jpg',
                            prefixIcon: Icon(Icons.link, size: 18),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Primary submit button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlack,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isUploading
                          ? null
                          : () async {
                              setModalState(() => isUploading = true);

                              if (selectedImageBytes != null) {
                                final res = await sessionService.uploadProofOfPayment(
                                  orderId: order.id,
                                  imageBytes: selectedImageBytes!,
                                  fileExtension: selectedExtension ?? 'jpg',
                                );

                                if (modalCtx.mounted) {
                                  Navigator.of(modalCtx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success ? AppTheme.successGreen : Colors.red,
                                    ),
                                  );
                                }
                              } else if (urlCtrl.text.trim().isNotEmpty) {
                                final res = await sessionService.submitPaymentProof(
                                  orderId: order.id,
                                  proofUrl: urlCtrl.text.trim(),
                                );

                                if (modalCtx.mounted) {
                                  Navigator.of(modalCtx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success ? AppTheme.successGreen : Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() => isUploading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please choose a receipt photo or enter a link first.'),
                                  ),
                                );
                              }
                            },
                      child: isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              selectedImageBytes != null
                                  ? (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty
                                      ? 'Upload & Replace Receipt'
                                      : 'Upload & Verify Receipt')
                                  : (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty
                                      ? 'Keep Existing Receipt'
                                      : 'Save Proof of Payment'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final orders = sessionService.userOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Procurement Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isRefreshing && orders.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.sheinCoral))
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: orders.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: orders.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildHeaderSummary(orders);
                        }
                        final order = orders[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: _buildOrderCard(context, sessionService, order),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildHeaderSummary(List<SessionOrderModel> orders) {
    final pendingCount = orders.where((o) => o.paymentStatus == PaymentStatus.pendingPayment).length;
    final confirmedCount = orders.where((o) => o.paymentStatus == PaymentStatus.paid).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryChip('Total Orders', '${orders.length}', AppTheme.primaryBlack),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildSummaryChip('Awaiting Payment', '$pendingCount', Colors.orange.shade800),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildSummaryChip('Confirmed', '$confirmedCount', Colors.green.shade700),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    SessionService sessionService,
    SessionOrderModel order,
  ) {
    Color statusColor;
    switch (order.paymentStatus) {
      case PaymentStatus.pendingPayment:
        statusColor = Colors.orange;
        break;
      case PaymentStatus.verifying:
        statusColor = Colors.blue;
        break;
      case PaymentStatus.paid:
        statusColor = Colors.green;
        break;
      case PaymentStatus.rejected:
        statusColor = Colors.red;
        break;
    }

    String dateStr = 'Recent Order';
    if (order.createdAt != null) {
      try {
        dateStr = DateFormat('MMM d, yyyy • h:mm a').format(order.createdAt!.toLocal());
      } catch (_) {
        dateStr = order.createdAt!.toLocal().toString().split('.')[0];
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.shopping_bag_outlined, color: statusColor, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                order.sessionCode ?? 'Procurement Batch',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.paymentStatus.displayName,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MWK ${_currencyFormat.format(order.totalCostLocal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.sheinCoral,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items in this Order:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${order.items.length} item${order.items.length > 1 ? "s" : ""}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        if (item.imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              item.imageUrl,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (c, o, s) => const Icon(Icons.image, size: 46),
                            ),
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.selectedOption ?? "Standard"} • Qty: ${item.quantity}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'MWK ${_currencyFormat.format(item.priceLocal * item.quantity)} (\$${(item.priceUsd * item.quantity).toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.sheinCoral,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Link leading to item on SheIn using the browser
                        IconButton(
                          icon: const Icon(Icons.travel_explore, color: AppTheme.sheinCoral, size: 22),
                          tooltip: 'Open on Shein',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  body: BrowserScreen(initialUrl: item.productUrl),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                // Bottom actions for this order
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Remove Order only if session is not locked
                    if (order.canRemove)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Remove Order', style: TextStyle(fontSize: 12)),
                        onPressed: () => _confirmRemoveOrder(sessionService, order),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Batch ${order.sessionStatus?.displayName ?? "Locked"} (Locked)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Proof of Payment action (Upload / Change Modal)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                            ? Colors.teal
                            : AppTheme.primaryBlack,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                            ? Icons.published_with_changes
                            : Icons.upload_file,
                        size: 16,
                      ),
                      label: Text(
                        (order.proofOfPaymentUrl != null && order.proofOfPaymentUrl!.isNotEmpty)
                            ? 'Change Proof'
                            : 'Upload Proof',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showProofOfPaymentModal(context, sessionService, order),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Orders Placed Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'When you capture products from Shein and place an order during an open procurement session, your orders and their delivery status will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sheinCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.travel_explore),
              label: const Text('Browse Shein & Start Order'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const Scaffold(body: BrowserScreen())),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
