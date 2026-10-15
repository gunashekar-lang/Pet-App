import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lazily-initialised Supabase client plus the resolved project settings.
///
/// Every screen goes through [client] rather than constructing its own, so the
/// app talks to exactly one session.
class SupabaseConfig {
  SupabaseConfig._();

  static SupabaseClient? _client;

  /// Test seam. When true, [ensureInit] reports "no credentials" even if a real
  /// `.env` or `--dart-define` is present, so a developer's own project cannot
  /// change which code path a test exercises.
  @visibleForTesting
  static bool? debugForceMissingCredentials;

  static bool get isInitialised => _client != null;

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError(
        'Supabase has not been initialised. Call SupabaseConfig.ensureInit() '
        'during startup.',
      );
    }
    return c;
  }
  /// Resolves credentials and opens the session.
  ///
  /// `--dart-define` wins over `.env` so CI builds can inject values without
  /// checking in a file. Returns false when neither source supplies both keys,
  /// which lets the caller surface a readable error instead of crashing.
  static Future<bool> ensureInit({bool loadEnvFile = true}) async {
    if (_client != null) return true;

    var url = const String.fromEnvironment('SUPABASE_URL');
    var key = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

    if ((url.isEmpty || key.isEmpty) && loadEnvFile) {
      try {
        await dotenv.load(fileName: '.env');
        url = url.isNotEmpty ? url : (dotenv.maybeGet('SUPABASE_URL') ?? '');
        // Accept the older name too so an existing .env keeps working.
        key = key.isNotEmpty
            ? key
            : (dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY') ??
                  dotenv.maybeGet('SUPABASE_ANON_KEY') ??
                  '');
      } catch (_) {
        // No .env present (or unreadable under `flutter test`). Fall through
        // so the dart-define values, if any, still get a chance to apply.
      }
    }

    if (debugForceMissingCredentials ?? false) {
      url = '';
      key = '';
    }

    if (url.isEmpty || key.isEmpty) {
      debugPrint(
        'Supabase not configured. Copy .env.example to .env and set '
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, or build with '
        '--dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
      return false;
    }

    try {
      await Supabase.initialize(url: url, publishableKey: key);
      _client = Supabase.instance.client;
      return true;
    } catch (e) {
      debugPrint('Supabase initialisation failed: $e');
      return false;
    }
  }

  /// Test seam — installs a pre-built client without touching the network.
  @visibleForTesting
  static void debugSetClient(SupabaseClient? client) => _client = client;

  @visibleForTesting
  static void debugReset() {
    _client = null;
    debugForceMissingCredentials = null;
  }
}
