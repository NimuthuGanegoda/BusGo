import 'package:flutter/material.dart';

enum BusgoAlertType { success, error, warning, info }

/// Shows a beautiful neon-glow alert overlay.
/// Inspired by Codepen "Error, Success, Warning and Alert Messages"
///
/// Usage:
///   BusgoAlert.show(context, type: BusgoAlertType.success, message: 'Payment successful!');
///   BusgoAlert.show(context, type: BusgoAlertType.error, title: 'Oh snap!', message: 'Payment failed.');
class BusgoAlert {
  static void show(
    BuildContext context, {
    required BusgoAlertType type,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _BusgoAlertWidget(
        type: type,
        title: title,
        message: message,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _BusgoAlertWidget extends StatefulWidget {
  final BusgoAlertType type;
  final String? title;
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _BusgoAlertWidget({
    required this.type,
    this.title,
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_BusgoAlertWidget> createState() => _BusgoAlertWidgetState();
}

class _BusgoAlertWidgetState extends State<_BusgoAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto dismiss
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: config.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: config.borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: config.glowColor,
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left accent bar
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: config.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon
                    Icon(config.icon, color: config.accentColor, size: 22),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: config.accentColor,
                              ),
                            ),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              color: config.textColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(Icons.close, size: 16, color: config.accentColor.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _AlertConfig _getConfig() {
    switch (widget.type) {
      case BusgoAlertType.success:
        return _AlertConfig(
          icon: Icons.check_circle_outline,
          accentColor: const Color(0xFF0AD406),
          bgColor: const Color(0xFF071710).withOpacity(0.95),
          borderColor: const Color(0xFF24F106).withOpacity(0.46),
          glowColor: const Color(0xFF259C08).withOpacity(0.3),
          textColor: const Color(0xFFB8FFB8),
        );
      case BusgoAlertType.error:
        return _AlertConfig(
          icon: Icons.cancel_outlined,
          accentColor: const Color(0xFFFF0303),
          bgColor: const Color(0xFF170707).withOpacity(0.95),
          borderColor: const Color(0xFFF10606).withOpacity(0.46),
          glowColor: const Color(0xFFFF0303).withOpacity(0.3),
          textColor: const Color(0xFFFFB8B8),
        );
      case BusgoAlertType.warning:
        return _AlertConfig(
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFFFB103),
          bgColor: const Color(0xFF171007).withOpacity(0.95),
          borderColor: const Color(0xFFF18E06).withOpacity(0.46),
          glowColor: const Color(0xFFFFB103).withOpacity(0.3),
          textColor: const Color(0xFFFFE8B8),
        );
      case BusgoAlertType.info:
        return _AlertConfig(
          icon: Icons.info_outline,
          accentColor: const Color(0xFF0396FF),
          bgColor: const Color(0xFF070D17).withOpacity(0.95),
          borderColor: const Color(0xFF062CF1).withOpacity(0.46),
          glowColor: const Color(0xFF0396FF).withOpacity(0.3),
          textColor: const Color(0xFFB8DFFF),
        );
    }
  }
}

class _AlertConfig {
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final Color glowColor;
  final Color textColor;

  _AlertConfig({
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.glowColor,
    required this.textColor,
  });
}
