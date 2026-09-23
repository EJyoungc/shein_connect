import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_config.dart';
import '../core/errors/app_logger.dart';
import '../core/services/supabase_service.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../utils/validators.dart';

/// Authentication service operating directly against Supabase Auth and public.profiles.
/// Strictly uses live Supabase backend with no local mock scopes or hardcoded credentials.
class AuthService extends ChangeNotifier {
  static const String _currentUserKey = 'shein_pro_current_user';

  UserModel? _currentUser;
  ProfileModel? _currentProfile;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  ProfileModel? get currentProfile => _currentProfile;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isAdmin => _currentProfile?.isAdmin ?? false;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check if Supabase session is active
    if (AppConfig.isSupabaseConfigured) {
      final supaClient = SupabaseService.clientOrNull;
      final session = supaClient?.auth.currentSession;
      if (session != null && supaClient?.auth.currentUser != null) {
        await _fetchAndSyncSupabaseProfile(supaClient!.auth.currentUser!);
      }

      // Listen for incoming auth state changes (e.g. from deep link verification)
      supaClient?.auth.onAuthStateChange.listen((data) async {
        final AuthChangeEvent event = data.event;
        final Session? newSession = data.session;
        if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) && newSession?.user != null) {
          await _fetchAndSyncSupabaseProfile(newSession!.user);
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          _currentProfile = null;
          notifyListeners();
        }
      });
    }

    // 2. Fallback to cached profile if available
    if (_currentUser == null) {
      final sessionUserJson = prefs.getString(_currentUserKey);
      if (sessionUserJson != null) {
        try {
          _currentUser = UserModel.fromJson(jsonDecode(sessionUserJson));
        } catch (e) {
          AppLogger.error('Error restoring local cached user session', e, null, 'AuthService');
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Register user directly with Supabase Auth + public.profiles
  Future<({bool success, String message})> register(UserModel newUser) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase authentication service is not configured.');
    }

    final cleanMobile = Validators.cleanMalawianNumber(newUser.mobile);
    final cleanEmail = newUser.email.trim().toLowerCase();

    try {
      final supaClient = SupabaseService.client;
      final response = await supaClient.auth.signUp(
        email: cleanEmail,
        password: newUser.password ?? '',
        emailRedirectTo: 'sheinproc://login-callback',
        data: {
          'full_name': newUser.fullName.trim(),
          'phone_number': cleanMobile,
          'role': 'customer',
        },
      );

      final user = response.user;
      if (user != null) {
        // Upsert public.profiles directly to guarantee consistency
        try {
          await supaClient.from('profiles').upsert({
            'id': user.id,
            'full_name': newUser.fullName.trim(),
            'phone_number': cleanMobile,
            'role': 'customer',
            'email': cleanEmail,
          });
        } catch (e) {
          AppLogger.warning('Direct profiles insert notice: $e', 'AuthService');
        }

        if (response.session != null) {
          await _fetchAndSyncSupabaseProfile(user);
          return (success: true, message: 'Registration successful! Welcome to SheIn Connect.');
        } else {
          return (success: true, message: 'Registration successful! Please check your email to confirm your account.');
        }
      }

      return (success: false, message: 'Registration failed. No user was returned by Supabase.');
    } on AuthException catch (e) {
      AppLogger.warning('Supabase sign-up error: ${e.message}', 'AuthService');
      return (success: false, message: e.message);
    } catch (e) {
      AppLogger.error('Supabase sign-up exception', e, null, 'AuthService');
      return (success: false, message: 'Registration failed: ${e.toString()}');
    }
  }

  /// Login directly with Supabase via either Email OR Malawian Mobile + Password
  Future<({bool success, String message, bool isEmailNotConfirmed, String? unconfirmedEmail})> login(
    String identifier,
    String password,
  ) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (
        success: false,
        message: 'Supabase authentication service is not configured.',
        isEmailNotConfirmed: false,
        unconfirmedEmail: null,
      );
    }

    final trimmedId = identifier.trim();
    if (trimmedId.isEmpty) {
      return (
        success: false,
        message: 'Please enter your email or mobile number.',
        isEmailNotConfirmed: false,
        unconfirmedEmail: null,
      );
    }
    if (password.isEmpty) {
      return (
        success: false,
        message: 'Please enter your password.',
        isEmailNotConfirmed: false,
        unconfirmedEmail: null,
      );
    }

    final isPhone = RegExp(r'^[+0-9]').hasMatch(trimmedId) && !trimmedId.contains('@');
    final normalizedId = isPhone ? Validators.cleanMalawianNumber(trimmedId) : trimmedId.toLowerCase();

    String? targetEmail;
    try {
      final supaClient = SupabaseService.client;

      if (!isPhone) {
        targetEmail = normalizedId;
      } else {
        // 1. Look up email associated with phone using the secure Supabase RPC function
        try {
          final rpcEmail = await supaClient.rpc<String?>(
            'get_email_by_phone',
            params: {'phone_input': trimmedId},
          );
          if (rpcEmail != null && rpcEmail.isNotEmpty) {
            targetEmail = rpcEmail;
          }
        } catch (e) {
          AppLogger.warning('Supabase get_email_by_phone RPC notice: $e', 'AuthService');
        }

        // 2. Fallback lookup in profiles table with phone variants
        if (targetEmail == null || targetEmail.isEmpty) {
          final phoneVariants = [
            normalizedId,
            trimmedId,
            if (normalizedId.startsWith('0')) '+265${normalizedId.substring(1)}',
            if (trimmedId.startsWith('+265')) '0${trimmedId.substring(4)}',
          ];
          try {
            final rows = await supaClient
                .from('profiles')
                .select('email')
                .filter('phone_number', 'in', phoneVariants)
                .limit(1);

            if (rows.isNotEmpty) {
              final row = rows.first;
              targetEmail = row['email'] as String?;
            }
          } catch (e) {
            AppLogger.warning('Supabase profiles query notice: $e', 'AuthService');
          }
        }

        if (targetEmail == null || targetEmail.isEmpty) {
          return (
            success: false,
            message: 'No account found with mobile number "$trimmedId". Please check your number or register.',
            isEmailNotConfirmed: false,
            unconfirmedEmail: null,
          );
        }
      }

      // Perform live Supabase sign-in
      final response = await supaClient.auth.signInWithPassword(
        email: targetEmail,
        password: password,
      );

      if (response.user != null) {
        await _fetchAndSyncSupabaseProfile(response.user!);
        final name = _currentProfile?.fullName ?? _currentUser?.fullName ?? 'Customer';
        return (
          success: true,
          message: 'Welcome back, $name!',
          isEmailNotConfirmed: false,
          unconfirmedEmail: null,
        );
      }

      return (
        success: false,
        message: 'Login failed. Please verify your credentials.',
        isEmailNotConfirmed: false,
        unconfirmedEmail: null,
      );
    } on AuthException catch (e) {
      AppLogger.warning('Supabase login error: ${e.message}', 'AuthService');
      final isEmailNotConfirmed = e.message.toLowerCase().contains('email not confirmed') ||
          (e.code?.toLowerCase().contains('email_not_confirmed') ?? false);
      if (isEmailNotConfirmed) {
        return (
          success: false,
          message: 'Your email has not been confirmed yet. Please check your inbox for the confirmation link.',
          isEmailNotConfirmed: true,
          unconfirmedEmail: targetEmail,
        );
      }
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return (
          success: false,
          message: 'Incorrect ${isPhone ? "mobile number" : "email"} or password. Please try again.',
          isEmailNotConfirmed: false,
          unconfirmedEmail: null,
        );
      }
      return (
        success: false,
        message: e.message,
        isEmailNotConfirmed: false,
        unconfirmedEmail: null,
      );
    } catch (e) {
      AppLogger.error('Supabase login exception', e, null, 'AuthService');
      return (
        success: false,
        message: 'Login failed: ${e.toString()}',
        isEmailNotConfirmed: false,
        unconfirmedEmail: null,
      );
    }
  }

  /// Resends the signup confirmation email to the specified email address.
  Future<({bool success, String message})> resendConfirmationEmail(String email) async {
    if (!AppConfig.isSupabaseConfigured) {
      return (success: false, message: 'Supabase authentication service is not configured.');
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return (success: false, message: 'Please provide a valid email address to resend confirmation.');
    }

    try {
      final supaClient = SupabaseService.client;
      await supaClient.auth.resend(
        type: OtpType.signup,
        email: cleanEmail,
        emailRedirectTo: 'sheinproc://login-callback',
      );
      return (
        success: true,
        message: 'Confirmation email sent to $cleanEmail. Please check your inbox and spam folder.',
      );
    } on AuthException catch (e) {
      AppLogger.warning('Resend confirmation error: ${e.message}', 'AuthService');
      return (success: false, message: e.message);
    } catch (e) {
      AppLogger.error('Resend confirmation exception', e, null, 'AuthService');
      return (success: false, message: 'Failed to resend confirmation email: ${e.toString()}');
    }
  }

  Future<void> _fetchAndSyncSupabaseProfile(User user) async {
    final supaClient = SupabaseService.clientOrNull;
    ProfileModel? profile;

    if (supaClient != null) {
      try {
        final data = await supaClient.from('profiles').select().eq('id', user.id).maybeSingle();
        if (data != null) {
          profile = ProfileModel.fromJson(data);
        }
      } catch (e) {
        AppLogger.warning('Could not fetch remote profile: $e', 'AuthService');
      }
    }

    profile ??= ProfileModel(
      id: user.id,
      fullName: user.userMetadata?['full_name'] as String? ?? user.email?.split('@').first ?? 'Customer',
      phoneNumber: user.userMetadata?['phone_number'] as String? ?? '',
      role: UserRole.fromString(user.userMetadata?['role'] as String?),
    );

    _currentProfile = profile;
    _currentUser = UserModel(
      id: user.id,
      fullName: profile.fullName,
      email: user.email ?? '',
      mobile: profile.phoneNumber,
      gender: 'Other',
    );

    final prefs = await SharedPreferences.getInstance();
    await _saveLocalSession(_currentUser!, prefs, profile.role);
  }

  Future<void> _saveLocalSession(UserModel user, SharedPreferences prefs, [UserRole? role]) async {
    _currentUser = user;
    final userRole = role ?? (user.email.toLowerCase().contains('admin') ? UserRole.admin : UserRole.customer);
    _currentProfile = ProfileModel(
      id: user.id,
      fullName: user.fullName,
      phoneNumber: user.mobile,
      role: userRole,
    );
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    notifyListeners();
  }

  /// Continue as guest
  void continueAsGuest() {
    _currentUser = UserModel(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      fullName: 'Guest Shopper',
      email: 'guest@sheinconnect.mw',
      mobile: '0880000000',
      gender: 'Other',
    );
    _currentProfile = ProfileModel(
      id: _currentUser!.id,
      fullName: 'Guest Shopper',
      phoneNumber: '0880000000',
      role: UserRole.customer,
    );
    notifyListeners();
  }

  /// Logout directly from Supabase session
  Future<void> logout() async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        await SupabaseService.clientOrNull?.auth.signOut();
      } catch (e) {
        AppLogger.warning('Supabase sign-out notice: $e', 'AuthService');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    _currentUser = null;
    _currentProfile = null;
    notifyListeners();
  }
}
