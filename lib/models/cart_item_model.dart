class CartItem {
  final String id;
  final String url;
  final String name;
  final String price;
  final double numericPrice;
  final String currency;
  final String? imageUrl;
  final String? variation;
  final String? color;
  final String? size;
  final String? description;
  final int quantity;
  final DateTime addedAt;
  final String? notes;

  CartItem({
    required this.id,
    required this.url,
    required this.name,
    required this.price,
    required this.numericPrice,
    this.currency = '\$',
    this.imageUrl,
    this.variation,
    this.color,
    this.size,
    this.description,
    this.quantity = 1,
    DateTime? addedAt,
    this.notes,
  }) : addedAt = addedAt ?? DateTime.now();

  double get totalPrice => numericPrice * quantity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'price': price,
        'numericPrice': numericPrice,
        'currency': currency,
        'imageUrl': imageUrl,
        'variation': variation,
        'color': color,
        'size': size,
        'description': description,
        'quantity': quantity,
        'addedAt': addedAt.toIso8601String(),
        'notes': notes,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        name: json['name'] as String? ?? 'Shein Item',
        price: json['price'] as String? ?? '\$0.00',
        numericPrice: (json['numericPrice'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? '\$',
        imageUrl: json['imageUrl'] as String?,
        variation: json['variation'] as String?,
        color: json['color'] as String?,
        size: json['size'] as String?,
        description: json['description'] as String?,
        quantity: json['quantity'] as int? ?? 1,
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        notes: json['notes'] as String?,
      );

  /// Converts from Supabase public.cart_items row
  factory CartItem.fromDb(Map<String, dynamic> row) {
    final priceUsd = (row['price_usd'] as num?)?.toDouble() ?? 0.0;
    return CartItem(
      id: row['id'] as String,
      url: row['product_url'] as String? ?? '',
      name: row['product_name'] as String? ?? 'Shein Item',
      price: '\$${priceUsd.toStringAsFixed(2)}',
      numericPrice: priceUsd,
      currency: '\$',
      imageUrl: row['image_url'] as String?,
      variation: row['selected_option'] as String?,
      quantity: 1,
      addedAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'] as String) : null,
    );
  }

  /// Converts to Supabase public.cart_items insert payload
  Map<String, dynamic> toDbInsert(String userId) {
    return {
      'user_id': userId,
      'product_name': name,
      'product_url': url,
      'image_url': imageUrl ?? '',
      'price_usd': numericPrice,
      'selected_option': [variation, color, size].whereType<String>().where((s) => s.isNotEmpty).join(' / '),
    };
  }

  CartItem copyWith({
    String? id,
    String? url,
    String? name,
    String? price,
    double? numericPrice,
    String? currency,
    String? imageUrl,
    String? variation,
    String? color,
    String? size,
    String? description,
    int? quantity,
    DateTime? addedAt,
    String? notes,
  }) {
    return CartItem(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      price: price ?? this.price,
      numericPrice: numericPrice ?? this.numericPrice,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      variation: variation ?? this.variation,
      color: color ?? this.color,
      size: size ?? this.size,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Helper to extract numeric price from string like "$15.99" or "USD 19.90"
  static double parsePriceToNumber(String priceStr) {
    try {
      final sanitized = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(sanitized) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
