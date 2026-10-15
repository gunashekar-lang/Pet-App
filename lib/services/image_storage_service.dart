import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Uploads picked images to Supabase Storage and hands back a public URL.
///
/// Picking a photo only produces a path inside the app's private cache, which
/// no other device and no other user can read. A database row holding
/// `/data/user/0/com.example.pet_super_app/cache/xyz.jpg` is therefore useless:
/// the row survives, but the image never loads again. Uploading is what makes a
/// listing visible to buyers.
///
/// Every method degrades to the local path when Supabase is not configured, so
/// the offline demo flow keeps working unchanged.
class ImageStorageService {
  ImageStorageService._();

  static final ImageStorageService instance = ImageStorageService._();

  /// Buckets created by `supabase/schema.sql`.
  static const String avatarBucket = 'avatars';
  static const String petBucket = 'pet-images';
  static const String productBucket = 'product-images';

  /// Extensions the buckets accept.
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  bool get _backendReady =>
      SupabaseConfig.isInitialised &&
      SupabaseConfig.client.auth.currentSession != null;

  /// Uploads [localPath] and returns the URL to persist.
  ///
  /// [folder] scopes the object name, typically the owner's user id, so a user
  /// can only ever write under their own prefix.
  Future<String> upload({
    required String localPath,
    required String bucket,
    required String folder,
    int width = 1600,
    int quality = 85,
  }) async {
    if (localPath.trim().isEmpty) return '';
    // Already a remote URL: re-uploading would duplicate the object.
    if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
      return localPath;
    }
    if (!_backendReady) return localPath;

    final extension = _extensionOf(localPath);
    if (!_allowedExtensions.contains(extension)) return localPath;

    try {
      // Web has no filesystem: picked photos arrive as blob: or data: URLs.
      // dart:io File cannot read them (and does not exist on web), so fetch
      // the bytes through the browser's HTTP stack instead.
      final Uint8List bytes;
      if (kIsWeb) {
        if (localPath.startsWith('data:image/')) {
          final comma = localPath.indexOf(',');
          if (comma < 0) return localPath;
          bytes = base64Decode(localPath.substring(comma + 1));
        } else {
          final response = await http.get(Uri.parse(localPath));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            return localPath;
          }
          bytes = response.bodyBytes;
        }
      } else {
        final file = File(localPath);
        if (!file.existsSync()) return localPath;
        bytes = await file.readAsBytes();
      }
      return await _uploadBytes(bytes, bucket, folder, extension);
    } catch (e) {
      // A failed upload must not block the seller: the listing is still worth
      // creating, it just keeps a local-only photo.
      debugPrint('Image upload to $bucket failed: $e');
      return localPath;
    }
  }

  /// Uploads [bytes] under `<folder>/<timestamp>.<extension>` and returns the
  /// public URL.
  Future<String> _uploadBytes(
    Uint8List bytes,
    String bucket,
    String folder,
    String extension,
  ) async {
    final safeFolder = folder.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = '$safeFolder/$stamp.$extension';

    await SupabaseConfig.client.storage.from(bucket).uploadBinary(
      objectPath,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image',
        upsert: true,
      ),
    );

    return SupabaseConfig.client.storage
        .from(bucket)
        .getPublicUrl(objectPath);
  }

  /// Uploads a profile photo. Falls back to the local path when offline.
  Future<String> uploadAvatar({
    required String localPath,
    required String userId,
  }) {
    return upload(
      localPath: localPath,
      bucket: avatarBucket,
      folder: userId.isEmpty ? 'unknown' : userId,
      width: 1024,
      quality: 85,
    );
  }

  /// Uploads every photo of a pet listing, preserving order.
  Future<List<String>> uploadPetImages({
    required List<String> localPaths,
    required String userId,
  }) async {
    if (localPaths.isEmpty) return const [];

    final uploaded = <String>[];
    for (final path in localPaths) {
      uploaded.add(
        await upload(
          localPath: path,
          bucket: petBucket,
          folder: userId.isEmpty ? 'unknown' : userId,
        ),
      );
    }
    return uploaded;
  }

  /// Uploads the single photo of a product listing.
  Future<String> uploadProductImage({
    required String localPath,
    required String userId,
  }) {
    return upload(
      localPath: localPath,
      bucket: productBucket,
      folder: userId.isEmpty ? 'unknown' : userId,
    );
  }

  /// Lower-case extension without the dot, defaulting to `jpg` for camera files
  /// that arrive without one.
  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }
}