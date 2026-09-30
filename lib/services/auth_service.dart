import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';

/// Owns authentication state, the current [UserModel] and first-run flags.
///
/// Replace the bodies of [login] / [register] with HTTP calls and the rest of
/// the app keeps working unchanged.
class AuthService extends ChangeNotifier {
  AuthService();

  bool _isInitialising = true;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _hasSeenOnboarding = false;
  String? _error;
  UserModel? _user;

  bool get isInitialising => _isInitialising;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  String? get error => _error;
  UserModel? get user => _user;

  /// Safe accessor — most screens need a guaranteed user.
  UserModel get currentUser => _user ?? _fallbackUser;

  static const UserModel _fallbackUser = UserModel(
    id: 'u_guest',
    fullName: 'Guest',
    email: '',
    phone: '',
  );

  /// Restores the persisted session. Called once from the splash screen.
  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding =
          prefs.getBool(AppConstants.keyHasSeenOnboarding) ?? false;
      _isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;

      final raw = prefs.getString(AppConstants.keyUser);
      if (raw != null && raw.isNotEmpty) {
        // Lightweight encode/decode avoids pulling in a JSON dependency while
        // still showing the shape a real API response would take.
        _user = UserModel.fromJson(_decodeUser(raw));
      }
      if (_isLoggedIn && _user == null) {
        _user = _fallbackUser;
      }
    } catch (_) {
      // Ignore storage errors and fall back to a first-run state.
    } finally {
      _isInitialising = false;
      notifyListeners();
    }
  }

  Future<bool> completeOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyHasSeenOnboarding, true);
    } catch (_) {
      /* no-op */
    }
    return true;
  }

  /// Accepts either an email address or an Indian mobile number as the
  /// identifier. The backend call replaces the body; everything downstream
  /// only cares that [isLoggedIn] flips.
  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final id = identifier.trim();
    final phone = Validators.normalizeIndianPhone(id);
    final isPhone =
        phone.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(phone);

    await Future<void>.delayed(AppConstants.shortDelay);

    if (id.isEmpty || password.isEmpty) {
      _isLoading = false;
      _error = 'Enter your email or mobile number and password.';
      notifyListeners();
      return false;
    }

    if (!isPhone && !RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(id)) {
      _isLoading = false;
      _error = 'Enter a valid email address or 10-digit mobile number.';
      notifyListeners();
      return false;
    }

    // No authentication backend is connected yet, so there is nothing to
    // verify these credentials against. Wiring an API here is the only change
    // needed; every screen already reacts to [isLoggedIn].
    _isLoading = false;
    _error = 'Signing in is not available yet. Create an account to continue.';
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future<void>.delayed(AppConstants.networkDelay);

    _user = UserModel(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email,
      phone: phone,
      joinedAt: DateTime.now(),
    );
    _isLoggedIn = true;
    _isLoading = false;
    await _persistSession();
    notifyListeners();
    return true;
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await Future<void>.delayed(AppConstants.networkDelay);

    // Requires the platform's Google Sign-In integration, which lands with the
    // authentication backend.
    _isLoading = false;
    _error = 'Google sign-in is not available yet.';
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _user = null;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyIsLoggedIn);
      await prefs.remove(AppConstants.keyUser);
    } catch (_) {
      /* no-op */
    }
  }

  void updateProfile({
    String? fullName,
    String? phone,
    String? city,
    String? bio,
    String? avatarUrl,
  }) {
    if (_user == null) return;
    _user = _user!.copyWith(
      fullName: fullName,
      phone: phone,
      city: city,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    notifyListeners();
    _persistSession();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyIsLoggedIn, _isLoggedIn);
      if (_user != null) {
        await prefs.setString(AppConstants.keyUser, _encodeUser(_user!));
      }
    } catch (_) {
      /* no-op */
    }
  }

  String _encodeUser(UserModel u) =>
      'id=${Uri.encodeComponent(u.id)};name=${Uri.encodeComponent(u.fullName)};'
      'email=${Uri.encodeComponent(u.email)};phone=${Uri.encodeComponent(u.phone)};'
      'avatar=${Uri.encodeComponent(u.avatarUrl)};city=${Uri.encodeComponent(u.city)};'
      'bio=${Uri.encodeComponent(u.bio)}';

  Map<String, dynamic> _decodeUser(String raw) {
    final out = <String, dynamic>{};
    for (final part in raw.split(';')) {
      if (!part.contains('=')) continue;
      final idx = part.indexOf('=');
      out[part.substring(0, idx)] = Uri.decodeComponent(
        part.substring(idx + 1),
      );
    }
    return {
      'id': out['id'] ?? '',
      'fullName': out['name'] ?? '',
      'email': out['email'] ?? '',
      'phone': out['phone'] ?? '',
      'avatarUrl': out['avatar'] ?? '',
      'city': out['city'] ?? '',
      'bio': out['bio'] ?? '',
    };
  }
}
