import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A set of custom, non-Material interactive widgets designed to bypass 
/// the persistent GlobalKey 'ink renderer' issues on Flutter Web.
/// These widgets avoid the Material 'Ink' system entirely.

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? color;
  final BoxBorder? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        border: border ?? Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppButton extends StatefulWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? color;
  final TextStyle? textStyle;
  final double? height;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.onPressed,
    this.color,
    this.textStyle,
    this.height,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = widget.isLoading ? null : widget.onPressed;
    
    return GestureDetector(
      onTapDown: (_) { if (effectiveOnPressed != null) setState(() => _isPressed = true); },
      onTapUp: (_) { if (effectiveOnPressed != null) setState(() => _isPressed = false); },
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: effectiveOnPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isPressed ? 0.8 : 1.0,
        child: Container(
          height: widget.height ?? 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.onPressed == null ? Colors.grey.shade400 : (widget.color ?? AppColors.primaryAccent),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: widget.isLoading 
            ? const SizedBox(
                height: 20, 
                width: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ) 
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    widget.icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: widget.textStyle ?? const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      inherit: true,
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double? size;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size,
    this.tooltip,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget content = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered 
              ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))
              : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.icon, 
            size: widget.size ?? 22,
            color: widget.color,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}

class AppTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final double? fontSize;

  const AppTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.fontSize,
  });

  @override
  State<AppTextButton> createState() => _AppTextButtonState();
}

class _AppTextButtonState extends State<AppTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color ?? theme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: widget.fontSize ?? 14,
              decoration: _isHovered ? TextDecoration.underline : null,
              inherit: true,
            ),
          ),
        ),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
