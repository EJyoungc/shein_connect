import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_config.dart';
import '../core/errors/app_logger.dart';
import '../core/services/supabase_service.dart';
import '../models/cart_item_model.dart';

class CartService extends ChangeNotifier {
  static const String _cartKey = 'shein_pro_cart_items';
  // Standard conversion estimate for MWK (Malawian Kwacha)
  static const double usdToMwkRate = 1750.0;

  List<CartItem> _items = [];
  bool _isLoading = true;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get uniqueItemCount => _items.length;

  double get subtotalUsd => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get subtotalMwk => subtotalUsd * usdToMwkRate;
  double get totalPriceLocal => subtotalMwk;

  CartService() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    final supaClient = SupabaseService.clientOrNull;
    final userId = supaClient?.auth.currentUser?.id;

    // 1. If user is logged into Supabase, attempt to sync from public.cart_items
    if (AppConfig.isSupabaseConfigured && userId != null) {
      try {
        final rows = await supaClient!.from('cart_items').select().eq('user_id', userId);
        if ((rows as List).isNotEmpty) {
          // ignore: unnecessary_cast
          _items = (rows as List<Map<String, dynamic>>).map(CartItem.fromDb).toList();
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        AppLogger.warning('Notice fetching remote cart: $e', 'CartService');
      }
    }

    // 2. Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _items = decoded.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        AppLogger.error('Error loading local cart items', e, null, 'CartService');
        _items = [];
      }
    } else {
      _items = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_items.map((i) => i.toJson()).toList());
    await prefs.setString(_cartKey, jsonStr);
  }

  /// Add item to cart or increment quantity if matching link and variation exists
  Future<void> addItem(CartItem newItem) async {
    final existingIndex = _items.indexWhere(
      (item) => item.url == newItem.url && item.variation == newItem.variation,
    );

    if (existingIndex != -1) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + newItem.quantity,
      );
    } else {
      _items.insert(0, newItem);
    }

    await _persistLocal();

    // Sync to Supabase public.cart_items if authenticated
    final supaClient = SupabaseService.clientOrNull;
    final userId = supaClient?.auth.currentUser?.id;
    if (AppConfig.isSupabaseConfigured && userId != null) {
      try {
        await supaClient!.from('cart_items').insert(newItem.toDbInsert(userId));
      } catch (e) {
        AppLogger.warning('Notice syncing added cart item to Supabase: $e', 'CartService');
      }
    }

    notifyListeners();
  }

  /// Update item quantity
  Future<void> updateQuantity(String id, int quantity) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      await _persistLocal();
      notifyListeners();
    }
  }

  /// Remove item by id
  Future<void> removeItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _persistLocal();

    final supaClient = SupabaseService.clientOrNull;
    if (AppConfig.isSupabaseConfigured && supaClient?.auth.currentUser != null) {
      try {
        await supaClient!.from('cart_items').delete().eq('id', id);
      } catch (e) {
        AppLogger.warning('Notice removing cart item from Supabase: $e', 'CartService');
      }
    }

    notifyListeners();
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    _items.clear();
    await _persistLocal();

    final supaClient = SupabaseService.clientOrNull;
    final userId = supaClient?.auth.currentUser?.id;
    if (AppConfig.isSupabaseConfigured && userId != null) {
      try {
        await supaClient!.from('cart_items').delete().eq('user_id', userId);
      } catch (e) {
        AppLogger.warning('Notice clearing cart in Supabase: $e', 'CartService');
      }
    }

    notifyListeners();
  }
}
