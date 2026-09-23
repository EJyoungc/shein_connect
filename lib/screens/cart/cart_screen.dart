import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/cart_item_model.dart';
import '../../services/cart_service.dart';
import '../../services/session_service.dart';
import '../../utils/app_theme.dart';
import '../orders/my_orders_screen.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onBrowseSheinPressed;

  const CartScreen({super.key, this.onBrowseSheinPressed});

  void _shareCart(BuildContext context, CartService cartService) {
    if (cartService.items.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('🛍️ *SHEIN PROC MALAWI - MY ORDER LIST*');
    buffer.writeln('===================================');
    buffer.writeln('Total Items: ${cartService.itemCount}');
    buffer.writeln(
        'Estimated Total: \$${cartService.subtotalUsd.toStringAsFixed(2)} (~ MWK ${cartService.subtotalMwk.toStringAsFixed(0)})\n');

    for (int i = 0; i < cartService.items.length; i++) {
      final item = cartService.items[i];
      buffer.writeln('${i + 1}. *${item.name}*');
      buffer.writeln('   • Price: ${item.price} (Qty: ${item.quantity})');
      if (item.variation != null && item.variation!.isNotEmpty) {
        buffer.writeln('   • Variation: ${item.variation}');
      }
      if (item.description != null && item.description!.isNotEmpty) {
        buffer.writeln('   • Description: ${item.description}');
      }
      buffer.writeln('   • Link: ${item.url}\n');
    }
    buffer.writeln('Procured via Shein Proc App');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Order summary copied! Ready to paste into WhatsApp / Email.'),
          ],
        ),
        backgroundColor: AppTheme.primaryBlack,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmClearCart(BuildContext context, CartService cartService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Local Cart?'),
        content: const Text('Are you sure you want to remove all captured items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              minimumSize: const Size(80, 36),
            ),
            onPressed: () {
              cartService.clearCart();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Shein Proc Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, size: 22),
            tooltip: 'My Orders',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            },
          ),
          Consumer<CartService>(
            builder: (context, cartService, child) {
              if (cartService.items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, size: 22),
                tooltip: 'Clear Cart',
                onPressed: () => _confirmClearCart(context, cartService),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          if (cartService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cartService.items.isEmpty) {
            return _buildEmptyCartView(context);
          }

          return Column(
            children: [
              // Items List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: cartService.items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = cartService.items[index];
                    return _CartItemCard(item: item, cartService: cartService);
                  },
                ),
              ),

              // Bottom Order Summary
              _buildSummaryCard(context, cartService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCartView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.sheinCoralLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: AppTheme.sheinCoral,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Shein Proc Cart is Empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open the Shein browser, browse trending items, and tap "Capture to Cart" to collect products for procurement in Malawi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.explore_outlined, color: Colors.white),
              label: const Text('Browse Shein Products Now'),
              onPressed: onBrowseSheinPressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, CartService cartService) {
    final mwkFormatted = cartService.subtotalMwk
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Row Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL (${cartService.itemCount} items)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${cartService.subtotalUsd.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryBlack,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Malawi Kwacha (Est.)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      'MWK $mwkFormatted',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.sheinCoral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Share / Export Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Export List'),
                    onPressed: () => _shareCart(context, cartService),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Place Order'),
                    onPressed: () async {
                      final sessionService = Provider.of<SessionService>(context, listen: false);
                      final activeSession = sessionService.activeSession;

                      if (activeSession == null || !activeSession.status.canAcceptOrders) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot place order: Current procurement session is locked or closed.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      // Show Confirmation Dialog with calculated MWK price and session code
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Confirm Order (${activeSession.sessionCode})'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Items: ${cartService.itemCount}'),
                              const SizedBox(height: 6),
                              Text('USD Total: \$${cartService.subtotalUsd.toStringAsFixed(2)}'),
                              const SizedBox(height: 6),
                              Text(
                                'Local Price (MWK @ ${activeSession.exchangeRate.toStringAsFixed(0)}): MWK ${(cartService.subtotalUsd * activeSession.exchangeRate).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.sheinCoral),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Once submitted, your order snapshot will be recorded under this procurement session for admin verification.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlack),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Submit Order'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        final result = await sessionService.submitOrder(
                          sessionId: activeSession.id,
                          cartItems: cartService.items,
                          exchangeRate: activeSession.exchangeRate,
                        );

                        if (context.mounted) {
                          if (result.success) {
                            await cartService.clearCart();
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Order Placed Successfully!'),
                                content: Text(result.message),
                                actions: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlack),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                                      );
                                    },
                                    child: const Text('View My Orders'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final CartService cartService;

  const _CartItemCard({
    required this.item,
    required this.cartService,
  });

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open product link')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 80,
                  height: 96,
                  color: AppTheme.lightGray,
                  child: (item.imageUrl != null && item.imageUrl!.startsWith('http'))
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppTheme.sheinCoral,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlack,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Variation Badge
                    if (item.variation != null && item.variation!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGray,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.variation!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Price
                    Row(
                      children: [
                        Text(
                          item.price,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.sheinCoral,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '~ MWK ${(item.numericPrice * CartService.usdToMwkRate).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => cartService.removeItem(item.id),
              ),
            ],
          ),

          // Description if present
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],

          const Divider(height: 18),

          // Action row: Link Button & Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Open Original Link
              InkWell(
                onTap: () => _openLink(context, item.url),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_new, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        'View on Shein',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => cartService.updateQuantity(item.id, item.quantity - 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Icon(Icons.remove, size: 16),
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    InkWell(
                      onTap: () => cartService.updateQuantity(item.id, item.quantity + 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Icon(Icons.add, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
