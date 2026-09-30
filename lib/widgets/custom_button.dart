import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

enum ButtonSize { small, medium, large }

/// The app's primary button, used for all primary actions.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconTrailing,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.expand = true,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? iconTrailing;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool expand;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;

    final height = switch (size) {
      ButtonSize.small => 40.0,
      ButtonSize.medium => 52.0,
      ButtonSize.large => 58.0,
    };
    final fontSize = switch (size) {
      ButtonSize.small => 13.5,
      ButtonSize.medium => 15.0,
      ButtonSize.large => 16.0,
    };
    final iconSize = switch (size) {
      ButtonSize.small => 16.0,
      ButtonSize.medium => 19.0,
      ButtonSize.large => 20.0,
    };

    final isEnabled = onPressed != null && !isLoading;

    late final Widget child;
    final content = isLoading
        ? SizedBox(
            width: fontSize + 4,
            height: fontSize + 4,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(
                variant == ButtonVariant.primary ? Colors.white : accent,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (iconTrailing != null) ...[
                const SizedBox(width: 9),
                Icon(iconTrailing, size: iconSize),
              ],
            ],
          );

    final borderRadius = BorderRadius.circular(AppConstants.radiusSm + 2);

    switch (variant) {
      case ButtonVariant.primary:
        child = FilledButton(
          onPressed: isEnabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: accent.withValues(alpha: 0.4),
            minimumSize: Size(expand ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            elevation: 0,
          ),
          child: content,
        );
      case ButtonVariant.secondary:
        child = OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(
              color: isEnabled ? accent : scheme.outline,
              width: 1.4,
            ),
            minimumSize: Size(expand ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: content,
        );
      case ButtonVariant.ghost:
        child = TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: Size(expand ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: content,
        );
      case ButtonVariant.danger:
        child = OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(
              color: isEnabled ? scheme.error : scheme.outline,
              width: 1.4,
            ),
            minimumSize: Size(expand ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: content,
        );
    }

    return child;
  }
}

/// Compact square action used on cards (favourite, add to cart, share).
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.iconSize = 19,
    this.background,
    this.foreground,
    this.isActive = false,
    this.activeColor,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final bool isActive;
  final Color? activeColor;
  final String? tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = activeColor ?? scheme.primary;

    final button = Material(
      color: isActive ? accent : (background ?? Colors.white),
      shape: CircleBorder(
        side: BorderSide(
          color: isActive ? accent : Colors.white.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: badge != null
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: isActive ? Colors.white : (foreground ?? accent),
                    ),
                    Positioned(
                      right: -5,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(
                  icon,
                  size: iconSize,
                  color: isActive ? Colors.white : (foreground ?? accent),
                ),
        ),
      ),
    );

    // The label is carried by semantics rather than a hover tooltip, which
    // would add a mouse listener to every action on screen.
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Semantics(
      button: true,
      label: tooltip,
      child: ExcludeSemantics(child: button),
    );
  }
}
