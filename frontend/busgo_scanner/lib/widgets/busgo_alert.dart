import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BUSGO ALERT — Neon glass-style alert messages
// Matches the CodePen "error, success, warning and alert messages" design
// ═══════════════════════════════════════════════════════════════════════════

enum BusgoAlertType { success, info, warning, error }

class BusgoAlert {
  /// Show a neon-glow alert that slides down from the top.
  /// Auto-dismisses after [duration] (default 4 seconds).
  static void show(
    BuildContext context, {
    required BusgoAlertType type,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    final controller = _AlertAnimationController();

    entry = OverlayEntry(
      builder: (context) => _BusgoAlertOverlay(
        type: type,
        title: title,
        message: message,
        duration: duration,
        controller: controller,
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _AlertAnimationController {
  VoidCallback? dismiss;
}

class _BusgoAlertOverlay extends StatefulWidget {
  final BusgoAlertType type;
  final String title;
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;
  final _AlertAnimationController controller;

  const _BusgoAlertOverlay({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    required this.onDismiss,
    required this.controller,
  });

  @override
  State<_BusgoAlertOverlay> createState() => _BusgoAlertOverlayState();
}

class _BusgoAlertOverlayState extends State<_BusgoAlertOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // Icon animation
  late final AnimationController _iconController;

  // Glow pulse animation
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    // Slide in from top
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    // Icon bounce/pulse
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Glow pulse
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    // Start animations
    _slideController.forward();
    _iconController.repeat(reverse: true);

    // Auto-close timer
    _autoCloseTimer = Timer(widget.duration, _dismiss);

    widget.controller.dismiss = _dismiss;
  }

  void _dismiss() {
    _autoCloseTimer?.cancel();
    _slideController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _slideController.dispose();
    _iconController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(widget.type);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _dismiss,
            onHorizontalDragEnd: (_) => _dismiss(),
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    // Dark glassy background
                    color: config.bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: config.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: config.glowColor.withOpacity(0.3 * _glowAnimation.value),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: config.glowColor.withOpacity(0.1),
                        blurRadius: 2,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left accent bar
                      Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: config.accentColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: config.accentColor.withOpacity(0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Animated icon
                      _buildAnimatedIcon(config),
                      const SizedBox(width: 12),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: config.textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.8),
                                    offset: const Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: config.textColor.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    offset: const Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Close button (blinking like the CodePen)
                      _buildBlinkingClose(config),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(_AlertConfig config) {
    return AnimatedBuilder(
      animation: _iconController,
      builder: (context, _) {
        double scale = 1.0;
        double rotation = 0.0;

        switch (widget.type) {
          case BusgoAlertType.success:
            // Bounce (like faa-bounce)
            scale = 1.0 + (_iconController.value * 0.15);
            break;
          case BusgoAlertType.info:
            // Shake (like faa-shake)
            rotation = sin(_iconController.value * pi * 4) * 0.15;
            break;
          case BusgoAlertType.warning:
            // Flash (like faa-flash)
            scale = 1.0 + (sin(_iconController.value * pi) * 0.12);
            break;
          case BusgoAlertType.error:
            // Pulse (like faa-pulse)
            scale = 0.9 + (_iconController.value * 0.2);
            break;
        }

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              config.icon,
              color: config.accentColor,
              size: 24,
              shadows: [
                Shadow(
                  color: config.accentColor.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlinkingClose(_AlertConfig config) {
    return AnimatedBuilder(
      animation: _iconController,
      builder: (context, _) {
        // Blink effect like the CodePen's fa-times
        final opacity = (sin(_iconController.value * pi * 2) + 1) / 2;
        return GestureDetector(
          onTap: _dismiss,
          child: Opacity(
            opacity: 0.5 + (opacity * 0.5),
            child: Icon(
              Icons.close,
              color: config.accentColor,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Alert configuration — matches the CodePen neon color scheme
// ═══════════════════════════════════════════════════════════════════════════

class _AlertConfig {
  final Color bgColor;
  final Color borderColor;
  final Color glowColor;
  final Color accentColor;
  final Color textColor;
  final IconData icon;

  const _AlertConfig({
    required this.bgColor,
    required this.borderColor,
    required this.glowColor,
    required this.accentColor,
    required this.textColor,
    required this.icon,
  });
}

_AlertConfig _getConfig(BusgoAlertType type) {
  switch (type) {
    case BusgoAlertType.success:
      return const _AlertConfig(
        bgColor: Color(0x1F079542),       // rgba(7,149,66,0.12)
        borderColor: Color(0x7524F106),    // rgba(36,241,6,0.46)
        glowColor: Color(0xFF259C08),
        accentColor: Color(0xFF0AD406),    // neon green
        textColor: Color(0xFF0AD406),
        icon: Icons.check_circle_outlined,
      );
    case BusgoAlertType.info:
      return const _AlertConfig(
        bgColor: Color(0x1F074995),       // rgba(7,73,149,0.12)
        borderColor: Color(0x75062CF1),    // rgba(6,44,241,0.46)
        glowColor: Color(0xFF0396FF),
        accentColor: Color(0xFF0396FF),    // neon blue
        textColor: Color(0xFF0396FF),
        icon: Icons.info_outline,
      );
    case BusgoAlertType.warning:
      return const _AlertConfig(
        bgColor: Color(0x29DC8001),       // rgba(220,128,1,0.16)
        borderColor: Color(0xCFF18E06),    // rgba(241,142,6,0.81)
        glowColor: Color(0xFFFFB103),
        accentColor: Color(0xFFFFB103),    // neon amber
        textColor: Color(0xFFFFB103),
        icon: Icons.warning_amber_rounded,
      );
    case BusgoAlertType.error:
      return const _AlertConfig(
        bgColor: Color(0x29DC1101),       // rgba(220,17,1,0.16)
        borderColor: Color(0xCFF10606),    // rgba(241,6,6,0.81)
        glowColor: Color(0xFFFF0303),
        accentColor: Color(0xFFFF0303),    // neon red
        textColor: Color(0xFFFF0303),
        icon: Icons.cancel_outlined,
      );
  }
}


