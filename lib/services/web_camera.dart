import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_camera_impl_stub.dart'
    if (dart.library.html) 'web_camera_impl_web.dart' as impl;

/// Captures one photo with the browser camera when running on web and a camera
/// is available (secure context + getUserMedia). Returns null on non-web, on
/// permission denial, on devices without a camera, or when the user cancels.
/// Callers then fall back to [ImagePicker]'s native capture.
Future<Uint8List?> captureWebCameraImage({required BuildContext context}) {
  if (!kIsWeb) return Future.value(null);
  return impl.captureWebCameraImage(context: context);
}

/// Renders [bytes] as a JPEG data: URL, which the image widgets and the
/// uploader both accept on web (there is no filesystem path on web).
String bytesToJpegDataUri(Uint8List bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';