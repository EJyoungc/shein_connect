import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/procurement_session_model.dart';
import '../../models/profile_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/session_service.dart';
import '../services/supabase_service.dart';

/// Provider for the initialized Supabase client (nullable if not yet configured).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return SupabaseService.clientOrNull;
});

/// AuthService provider using Riverpod.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// CartService provider managed via Riverpod.
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService();
});

/// SessionService provider managed via Riverpod.
final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService();
});

/// Current active procurement session stream / state provider
final activeProcurementSessionProvider = Provider<ProcurementSessionModel?>((ref) {
  final sessionService = ref.watch(sessionServiceProvider);
  return sessionService.activeSession;
});

/// Current user profile provider
final currentUserProfileProvider = Provider<ProfileModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentProfile;
});
