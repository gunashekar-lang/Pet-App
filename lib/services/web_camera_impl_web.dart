import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Opens the browser camera (getUserMedia) in an in-app capture sheet and
/// returns the captured frame as JPEG bytes.
///
/// Returns null when getUserMedia is unavailable (no camera, insecure context,
/// permission denied) or when the user cancels. The caller then falls back to
/// image_picker, which on desktop browsers offers a file picker instead.
Future<Uint8List?> captureWebCameraImage({
  required BuildContext context,
}) async {
  final html.MediaStream? stream = await _openStream();
  if (stream == null) return null;
  if (!context.mounted) {
    stream.getTracks().forEach((track) => track.stop());
    return null;
  }

  Uint8List? result;
  try {
    final video = html.VideoElement()
      ..srcObject = stream
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.objectFit = 'cover'
      ..style.width = '100%'
      ..style.height = '100%';

    final viewType = 'pethub-camera-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => video,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CameraCaptureDialog(
        viewType: viewType,
        onShutter: () async {
          result = _snapshot(video);
          if (result != null && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );

    return result;
  } catch (_) {
    return null;
  } finally {
    stream.getTracks().forEach((track) => track.stop());
  }
}

Future<html.MediaStream?> _openStream() async {
  try {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) return null;
    return await devices.getUserMedia({
      'audio': false,
      'video': {'facingMode': 'environment'},
    });
  } catch (_) {
    return null;
  }
}

/// Draws the current video frame onto a canvas and exports it as JPEG bytes.
Uint8List? _snapshot(html.VideoElement video) {
  if (video.videoWidth == 0 || video.videoHeight == 0) return null;
  final canvas = html.CanvasElement(
    width: video.videoWidth,
    height: video.videoHeight,
  );
  final context = canvas.context2D
    ..fillStyle = '#000000'
    ..fillRect(0, 0, canvas.width!, canvas.height!);
  context.drawImage(video, 0, 0);

  final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
  if (dataUrl.isEmpty) return null;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  return base64Decode(dataUrl.substring(comma + 1));
}

class _CameraCaptureDialog extends StatelessWidget {
  const _CameraCaptureDialog({
    required this.viewType,
    required this.onShutter,
    required this.onCancel,
  });

  final String viewType;
  final VoidCallback onShutter;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Take a photo',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: HtmlElementView(viewType: viewType),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  IconButton.filled(
                    onPressed: onShutter,
                    iconSize: 36,
                    icon: const Icon(Icons.camera_alt_rounded),
                    tooltip: 'Capture',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}