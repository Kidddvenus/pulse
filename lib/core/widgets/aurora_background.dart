import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Select colors based on theme
    Color c1 = isDark ? AppColors.aurora1Dark : AppColors.aurora1Light;
    Color c2 = isDark ? AppColors.aurora2Dark : AppColors.aurora2Light;
    Color c3 = isDark ? AppColors.aurora3Dark : AppColors.aurora3Light;
    Color c4 = isDark ? AppColors.aurora4Dark : AppColors.aurora4Light;
    
    // Blend mode to simulate CSS multiply or screen
    BlendMode blendMode = isDark ? BlendMode.screen : BlendMode.multiply;

    return Stack(
      children: [
        // Base Background
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        
        // Animated Blobs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = _controller.value;
            // Use sin/cos to create organic floating movements
            double x1 = math.sin(value * math.pi * 2) * 50;
            double y1 = math.cos(value * math.pi * 2) * 50;
            
            double x2 = math.cos((value + 0.2) * math.pi * 2) * 70;
            double y2 = math.sin((value + 0.5) * math.pi * 2) * -60;

            double x3 = math.sin((value + 0.8) * math.pi * 2) * -40;
            double y3 = math.cos((value + 0.3) * math.pi * 2) * 80;

            return Stack(
              children: [
                _buildBlob(c1, Alignment(-0.8, -0.8), x1, y1, blendMode, 1.2),
                _buildBlob(c2, Alignment(0.8, -0.4), x2, y2, blendMode, 1.0),
                _buildBlob(c3, Alignment(-0.4, 0.8), x3, y3, blendMode, 1.1),
                _buildBlob(c4, Alignment(0.5, 0.5), -x1, -y1, blendMode, 1.3),
              ],
            );
          },
        ),

        // Blur Filter over blobs
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Content
        widget.child,
      ],
    );
  }

  Widget _buildBlob(Color color, Alignment align, double dx, double dy, BlendMode blendMode, double scale) {
    return Align(
      alignment: align,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.6),
              backgroundBlendMode: blendMode,
            ),
          ),
        ),
      ),
    );
  }
}
