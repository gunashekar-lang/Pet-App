import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'image_storage_service.dart';
import 'supabase_config.dart';

/// Owns authentication state, the current [UserModel] and first-run flags.
///
/// Backed by Supabase Auth. The public surface is unchanged from the original
/// in-memory implementation, so every screen keeps working as-is.
///
/// Phone sign-in is validated on the client but not yet sent to Supabase:
/// enabling OTP for phone numbers requires a Twilio account linked to the
/// project. Until then [login] returns a clear message for phone identifiers
/// rather than failing silently.
class AuthService extends ChangeNotifier {
  AuthService();

  bool _isInitialising = true;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _hasSeenOnboarding = false;
  String? _error;
  UserModel? _user;
  StreamSubscription<AuthState>? _authSub;

  bool get isInitialising => _isInitialising;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  String? get error => _error;
  UserModel? get user => _user;

  /// True when Supabase rejected the configured URL or anon key.
  bool get isBackendConfigured => _backendConfigured;
  bool _backendConfigured = false;

  /// Safe accessor — most screens need a guaranteed user.
  UserModel get currentUser => _user ?? _fallbackUser;

  static const UserModel _fallbackUser = UserModel(
    id: 'u_guest',
    fullName: 'Guest',
    email: '',
    phone: '',
  );

  /// Restores the session. Called once from the splash screen.
  ///
  /// Onboarding and the offline session both stay in [SharedPreferences]
  /// because they are device-local state, not account data. When Supabase is
  /// configured the session comes from there instead, which also gives us
  /// token refresh.
  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding =
          prefs.getBool(AppConstants.keyHasSeenOnboarding) ?? false;
    } catch (_) {
      // Ignore storage errors and fall back to a first-run state.
    }

    _backendConfigured = await SupabaseConfig.ensureInit();
    if (_backendConfigured) {
      _listenToAuthChanges();
      try {
        final session = SupabaseConfig.client.auth.currentSession;
        if (session != null) {
          _user = await _loadProfile(session.user.id);
          _isLoggedIn = true;
        }
      } catch (e) {
        _error = _friendlyAuthError(e);
      }
    } else {
      // Offline mode: restore the last local account so a restart does not
      // throw the user back to the sign-in screen.
      await _restoreLocalSession();
    }

    _isInitialising = false;
    notifyListeners();
  }

  /// Rebuilds the signed-in user from the stored local account.
  Future<void> _restoreLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppConstants.keyIsLoggedIn) != true) return;
      final raw = prefs.getString(AppConstants.keyUser);
      if (raw == null || raw.isEmpty) return;
      _user = UserModel.fromJson(_decodeUser(raw));
      _isLoggedIn = _user!.id.startsWith('local_');
    } catch (_) {
      /* no-op */
    }
  }

  /// Keeps local state in step with sign-in, sign-out and token refresh.
  void _listenToAuthChanges() {
    _authSub ??= SupabaseConfig.client.auth.onAuthStateChange.listen((
      AuthState state,
    ) async {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          _user = await _loadProfile(state.session?.user.id);
          _isLoggedIn = state.session != null;
          _error = null;
        case AuthChangeEvent.signedOut:
          _user = null;
          _isLoggedIn = false;
        default:
          return;
      }
      notifyListeners();
    });
  }

  /// Reads the profile row the signup trigger created, merged with the
  /// authoritative identity that lives in `auth.users`.
  Future<UserModel> _loadProfile(String? userId) async {
    if (userId == null) return _fallbackUser;
    final authUser = SupabaseConfig.client.auth.currentUser;
    var profile = <String, dynamic>{};
    try {
      final res = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res != null) profile = res;
    } catch (_) {
      // Fall back to auth metadata if the profile row is missing.
    }

    final meta = authUser?.userMetadata ?? const {};
    return UserModel.fromJson({
      'id': userId,
      'fullName':
          (profile['full_name'] as String?) ??
          (meta['full_name'] as String?) ??
          '',
      'email': (profile['email'] as String?) ?? authUser?.email ?? '',
      'phone': (profile['phone'] as String?) ?? (meta['phone'] as String?) ?? '',
      'avatarUrl':
          (profile['avatar_url'] as String?) ??
          (meta['avatar_url'] as String?) ??
          authUser?.userMetadata?['avatar_url'] ??
          '',
      'city': profile['city'] as String? ?? '',
      'bio': profile['bio'] as String? ?? '',
      'joinedAt': (profile['created_at'] as String?) ?? '',
    });
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

  /// Accepts either an email address or an Indian mobile number.
  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final id = identifier.trim();

    if (id.isEmpty || password.isEmpty) {
      return _fail('Enter your email or mobile number and password.');
    }

    final phone = Validators.normalizeIndianPhone(id);
    final isPhone = phone.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
    final isEmail = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(id);

    if (!isPhone && !isEmail) {
      return _fail('Enter a valid email address or 10-digit mobile number.');
    }

    if (!_backendConfigured) {
      return _loginLocally(
        identifier: id,
        password: password,
        isPhone: isPhone,
      );
    }

    if (isPhone) {
      // Validated, but Supabase cannot verify it yet — see the class doc.
      return _fail(
        'Sign in with mobile number is not available yet. Use your email '
        'address instead.',
      );
    }

    try {
      final res = await SupabaseConfig.client.auth.signInWithPassword(
        email: id,
        password: password,
      );
      if (res.session == null) {
        return _fail('Sign in failed. Check your email and password.');
      }
      _user = await _loadProfile(res.user!.id);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      return _fail(_friendlyAuthError(e));
    }
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

    if (fullName.trim().isEmpty) {
      return _fail('Enter your full name.');
    }
    final badEmail = Validators.email(email.trim());
    if (badEmail != null) return _fail(badEmail);
    final weak = Validators.password(password);
    if (weak != null) return _fail(weak);

    if (!_backendConfigured) {
      return _registerLocally(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
    }

    try {
      final res = await SupabaseConfig.client.auth.signUp(
        email: email.trim(),
        password: password,
        // The database trigger creates the profile row from these.
        data: {
          'full_name': fullName.trim(),
          'phone': Validators.normalizeIndianPhone(phone),
        },
        emailRedirectTo: 'pethub://auth/callback',
      );

      if (res.session == null) {
        // Email confirmation is on, so the user must confirm before a session
        // exists. That is success, not failure.
        return _fail(
          'Account created. Check your inbox and confirm your email to sign in.',
        );
      }

      _user = await _loadProfile(res.user!.id);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final message = _friendlyAuthError(e);
      // A duplicate email surfaces as a generic AuthApiException; make it
      // actionable instead of leaking the raw text.
      if (message.contains('already registered') ||
          message.contains('already been registered')) {
        return _fail('That email is already registered. Try signing in.');
      }
      return _fail(message);
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (!_backendConfigured) {
      return _fail(_notConfiguredMessage);
    }

    try {
      // Opens the platform browser / Google account chooser. The auth listener
      // installed in bootstrap flips state when the redirect completes.
      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'pethub://auth/callback',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      return _fail(_friendlyAuthError(e));
    }
  }

  Future<void> logout() async {
    if (_backendConfigured) {
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {
        // Local state still needs to clear even if the network call fails.
      }
    } else {
      // Offline mode: drop the cached session but keep the account, so the
      // user can sign back in without re-registering.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.keyIsLoggedIn);
        await prefs.remove(AppConstants.keyUser);
      } catch (_) {
        /* no-op */
      }
    }
    _isLoggedIn = false;
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? city,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_user == null) return false;

    // A picked photo is a path in the app's private cache, so it must be
    // uploaded before it can be stored or shown to anyone else.
    final avatar = await _resolveAvatar(avatarUrl);

    final updated = _user!.copyWith(
      fullName: fullName,
      phone: phone,
      city: city,
      bio: bio,
      avatarUrl: avatar,
    );
    _user = updated;
    notifyListeners();

    if (!_backendConfigured) {
      await _updateLocalAccount(updated);
      return true;
    }

    return _pushProfile(updated);
  }

  /// Uploads a newly picked avatar and returns the URL to persist. Falls back
  /// to the input when there is nothing new to upload.
  Future<String> _resolveAvatar(String? avatarUrl) async {
    if (avatarUrl == null || avatarUrl.isEmpty) return '';
    return ImageStorageService.instance.uploadAvatar(
      localPath: avatarUrl,
      userId: _user?.id ?? '',
    );
  }

  /// Mirrors a profile edit back into the offline account store.
  Future<void> _updateLocalAccount(UserModel u) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUser);
      if (raw == null) return;
      await prefs.setString(AppConstants.keyUser, _encodeUser(u));
    } catch (_) {
      /* no-op */
    }
  }

  /// Persists the profile row, then reports whether the backend accepted it.
  ///
  /// Errors are no longer swallowed: a silent failure is exactly why a missing
  /// column could go unnoticed for so long.
  Future<bool> _pushProfile(UserModel u) async {
    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({
            if (u.fullName.isNotEmpty) 'full_name': u.fullName,
            if (u.phone.isNotEmpty) 'phone': u.phone,
            if (u.city.isNotEmpty) 'city': u.city,
            if (u.bio.isNotEmpty) 'bio': u.bio,
            if (u.avatarUrl.isNotEmpty) 'avatar_url': u.avatarUrl,
          })
          .eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint('Profile sync failed: $e');
      return false;
    }
  }

  /// Signs in against a locally-stored account.
  ///
  /// This is the path taken when Supabase is not configured, so the app can be
  /// explored without a backend. Accounts live in [SharedPreferences] and are
  /// never sent anywhere. Passwords are compared as a plain string because
  /// there is no server to hash them for — this must not become the model for
  /// real auth.
  Future<bool> _loginLocally({
    required String identifier,
    required String password,
    required bool isPhone,
  }) async {
    await Future<void>.delayed(AppConstants.networkDelay);
    final accounts = await _readLocalAccounts();
    final match = _findAccount(accounts, identifier);

    if (match == null) {
      return _fail(
        'No local account for $identifier. Create one first, or add your '
        'Supabase key to .env for real sign-in.',
      );
    }
    if (match.password != password) {
      return _fail('Incorrect password for that local account.');
    }

    _user = UserModel(
      id: match.id,
      fullName: match.fullName,
      email: isPhone ? '' : identifier,
      phone: isPhone ? identifier : match.phone,
      joinedAt: match.createdAt,
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    await _persistSession();
    return true;
  }

  /// Creates a local account and signs straight in.
  Future<bool> _registerLocally({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(AppConstants.networkDelay);

    final cleanEmail = email.trim();
    final cleanPhone = Validators.normalizeIndianPhone(phone);
    final accounts = await _readLocalAccounts();
    final identifier = cleanPhone.isNotEmpty ? cleanPhone : cleanEmail;

    if (_findAccount(accounts, identifier) != null ||
        (cleanEmail.isNotEmpty && _findAccount(accounts, cleanEmail) != null) ||
        (cleanPhone.isNotEmpty && _findAccount(accounts, cleanPhone) != null)) {
      return _fail(
        'A local account already exists for $identifier. Sign in instead.',
      );
    }

    final account = _LocalAccount(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      identifier: identifier,
      password: password,
      fullName: fullName.trim(),
      email: cleanEmail,
      phone: cleanPhone,
      createdAt: DateTime.now(),
    );
    accounts[identifier] = account;
    await _writeLocalAccounts(accounts);

    _user = UserModel(
      id: account.id,
      fullName: account.fullName,
      email: cleanEmail,
      phone: cleanPhone,
      joinedAt: account.createdAt,
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    await _persistSession();
    return true;
  }

  /// Finds an account by email, phone or stored identifier.
  ///
  /// The sign-in form accepts either an email address or an Indian mobile
  /// number, so a lookup has to consider both rather than only the field the
  /// account happened to be filed under.
  _LocalAccount? _findAccount(
    Map<String, _LocalAccount> accounts,
    String identifier,
  ) {
    final key = identifier.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final account in accounts.values) {
      if (account.identifier.toLowerCase() == key ||
          account.email.toLowerCase() == key ||
          account.phone == Validators.normalizeIndianPhone(identifier)) {
        return account;
      }
    }
    return null;
  }

  Future<Map<String, _LocalAccount>> _readLocalAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localAccountsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(
          k as String,
          _LocalAccount.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeLocalAccounts(
    Map<String, _LocalAccount> accounts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localAccountsKey,
        jsonEncode(accounts.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {
      /* no-op */
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Shared tail for every failed attempt: clears loading, sets the message.
  bool _fail(String message) {
    _isLoading = false;
    _error = message;
    notifyListeners();
    return false;
  }

  /// Caches the offline session so a restart can restore it.
  ///
  /// Only used in offline mode; Supabase owns the real session.
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

  static const String _notConfiguredMessage =
      'Backend not configured. Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
      'to .env.';

  /// Key holding offline accounts in [SharedPreferences].
  static const String _localAccountsKey = 'local_accounts';

  /// Turns Supabase exceptions into something safe to show a user.
  static String _friendlyAuthError(Object e) {
    final raw = e is AuthException ? e.message : e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirm your email address before signing in.';
    }
    if (lower.contains('failed to fetch') ||
        lower.contains('network') ||
        lower.contains('connection')) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    return raw.replaceFirst('AuthException: ', '');
  }
}

/// A credential stored on-device so the app is explorable without a backend.
///
/// Deliberately plain: the password is not hashed because there is no server
/// to hash it for. These rows never leave the device and are dropped once
/// Supabase is configured, because real auth takes over.
class _LocalAccount {
  const _LocalAccount({
    required this.id,
    required this.identifier,
    required this.password,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String identifier;
  final String password;
  final String fullName;
  final String email;
  final String phone;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'identifier': identifier,
    'password': password,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _LocalAccount.fromJson(Map<String, dynamic> json) => _LocalAccount(
    id: json['id'] as String? ?? '',
    identifier: json['identifier'] as String? ?? '',
    password: json['password'] as String? ?? '',
    fullName: json['fullName'] as String? ?? 'Pet Lover',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}
