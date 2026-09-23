import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_item_model.dart';
import '../../services/cart_service.dart';
import '../../utils/app_theme.dart';

class ProductCaptureModal extends StatefulWidget {
  final CartItem initialData;

  const ProductCaptureModal({
    super.key,
    required this.initialData,
  });

  @override
  State<ProductCaptureModal> createState() => _ProductCaptureModalState();
}

class _ProductCaptureModalState extends State<ProductCaptureModal> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _variationController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;

  int _quantity = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.name);
    _priceController = TextEditingController(text: widget.initialData.price);
    _variationController = TextEditingController(
      text: widget.initialData.variation ??
          (widget.initialData.color != null ? 'Color: ${widget.initialData.color}' : 'Default'),
    );
    _descriptionController = TextEditingController(text: widget.initialData.description ?? '');
    _notesController = TextEditingController(text: widget.initialData.notes ?? '');
    _quantity = widget.initialData.quantity;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _variationController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveToCart() async {
    setState(() {
      _isSaving = true;
    });

    final rawPrice = CartItem.parsePriceToNumber(_priceController.text);
    final cartItem = CartItem(
      id: widget.initialData.id.isNotEmpty
          ? widget.initialData.id
          : 'item_${DateTime.now().millisecondsSinceEpoch}',
      url: widget.initialData.url,
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Shein Item',
      price: _priceController.text.trim().isNotEmpty
          ? _priceController.text.trim()
          : '\$0.00',
      numericPrice: rawPrice > 0 ? rawPrice : widget.initialData.numericPrice,
      currency: widget.initialData.currency,
      imageUrl: widget.initialData.imageUrl,
      variation: _variationController.text.trim(),
      description: _descriptionController.text.trim(),
      quantity: _quantity,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    final cartService = Provider.of<CartService>(context, listen: false);
    await cartService.addItem(cartItem);

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final double rawPrice = CartItem.parsePriceToNumber(_priceController.text);
    final double estimatedMwk = rawPrice * CartService.usdToMwkRate;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.sheinCoralLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: AppTheme.sheinCoral,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Captured from Shein',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlack,
                        ),
                      ),
                      Text(
                        'Review details & save to your local cart',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const Divider(height: 24),

            // Product Preview Card (Image + Details)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 96,
                    color: AppTheme.lightGray,
                    child: (widget.initialData.imageUrl != null &&
                            widget.initialData.imageUrl!.startsWith('http'))
                        ? Image.network(
                            widget.initialData.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            size: 36,
                            color: AppTheme.sheinCoral,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // URL & Quick Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'SHEIN PRODUCT LINK CAPTURED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.initialData.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (estimatedMwk > 0)
                        Text(
                          'Est: MWK ${estimatedMwk.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.sheinCoral,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Product Name Field
            const Text(
              'Product Name',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Price and Variations Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Captured Price',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _priceController,
                        readOnly: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                          fillColor: const Color(0xFFF1F3F5),
                          filled: true,
                          prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.black54),
                          prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          helperText: 'Verified Shein Price (Read Only)',
                          helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Variation / Color / Size',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _variationController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Color: Red / Size: L',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description / Specs
            const Text(
              'Description / Specifications',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Captured item details, material, fit, etc.',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            // Quantity Stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Quantity:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () {
                          setState(() => _quantity++);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Add to Cart Button
            ElevatedButton.icon(
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              label: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add to Shein Proc Cart'),
              onPressed: _isSaving ? null : _saveToCart,
            ),
          ],
        ),
      ),
    );
  }
}
