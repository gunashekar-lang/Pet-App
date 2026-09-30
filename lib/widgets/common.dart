import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Displays a user-picked image from a local file path, or a remote URL once a
/// backend provides one. Anything missing falls back to a neutral branded
/// gradient with an icon, so screens never show a broken image.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.icon = Icons.pets_rounded,
    this.borderRadius,
    this.gradientColors,
  });

  /// Either an absolute local file path (picked via camera/gallery) or an
  /// `http(s)` URL.
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData icon;
  final BorderRadius? borderRadius;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final placeholder = _ImagePlaceholder(
      width: width,
      height: height,
      icon: icon,
      colors: gradientColors,
    );

    final image = _buildImage(context, placeholder);

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _buildImage(BuildContext context, Widget placeholder) {
    if (url.trim().isEmpty) return placeholder;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      );
    }

    return Image.file(
      File(url),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    this.width,
    this.height,
    required this.icon,
    this.colors,
  });

  final double? width;
  final double? height;
  final IconData icon;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list =
        colors ??
        (scheme.brightness == Brightness.dark
            ? [AppColors.surfaceDark, const Color(0xFF221D30)]
            : [AppColors.lavender, AppColors.lavenderSoft]);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: list,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: scheme.brightness == Brightness.dark
              ? AppColors.lilac.withValues(alpha: 0.9)
              : AppColors.brand.withValues(alpha: 0.65),
          size: 32,
        ),
      ),
    );
  }
}

/// Rounded avatar used for sellers and users.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.url,
    required this.initials,
    this.size = 40,
    this.icon = Icons.person_rounded,
  });

  final String url;
  final String initials;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );

    if (url.trim().isEmpty) return fallback;
    return ClipOval(
      child: url.startsWith('http')
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : Image.file(
              File(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// A soft, rounded container used for most surfaces in the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppConstants.radiusMd,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = BorderRadius.circular(radius);
    return Material(
      color: color ?? theme.colorScheme.surface,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      elevation: elevated ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: borderColor ?? theme.colorScheme.outline),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Small pill label, e.g. "Verified" or "New arrival".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.solid = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool solid;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    final fg = solid ? Colors.white : base;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: solid ? base : base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon button used for back, share and favourite actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.background,
    this.foreground,
    this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Material(
      color: background ?? scheme.surface,
      shape: CircleBorder(side: BorderSide(color: scheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: iconSize, color: foreground ?? scheme.onSurface),
              if (badge > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.surface, width: 1.4),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // A tooltip is exposed as a semantics label instead of a hover overlay:
    // hover tracking on a mobile-first app only adds a mouse listener per
    // button, and constantly rebuilt hover regions trip Flutter's
    // MouseTracker device-update assertion.
    if (tooltip == null) return button;
    return Semantics(
      button: true,
      label: tooltip,
      child: ExcludeSemantics(child: button),
    );
  }
}
