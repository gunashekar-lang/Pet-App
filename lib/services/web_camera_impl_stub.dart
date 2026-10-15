import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Non-web platforms have no in-browser camera; the caller falls back to
/// the platform camera app via image_picker.
Future<Uint8List?> captureWebCameraImage({
  required BuildContext context,
}) async {
  return null;
}