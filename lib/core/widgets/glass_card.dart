import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24.0,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor = isDark ? AppColors.glassBgDark : AppColors.glassBgLight;
    Color borderColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.5) : const Color(0x33959DA5),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
