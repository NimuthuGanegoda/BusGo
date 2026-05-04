import 'dart:async';
import 'package:flutter/material.dart';

/// Full-screen payment processing overlay with scrolling bus-themed phrases.
/// Inspired by Corange Loading Screen Codepen.
///
/// Usage:
///   showDialog(
///     context: context,
///     barrierDismissible: false,
///     builder: (_) => const PaymentProcessingOverlay(),
///   );
///   // When done: Navigator.of(context).pop();
class PaymentProcessingOverlay extends StatefulWidget {
  const PaymentProcessingOverlay({super.key});

  @override
  State<PaymentProcessingOverlay> createState() =>
      _PaymentProcessingOverlayState();
}

class _PaymentProcessingOverlayState extends State<PaymentProcessingOverlay>
    with SingleTickerProviderStateMixin {
  static const _phrases = [
    'Calculating your fare',
    'Securing your seat',
    'Checking route availability',
    'Verifying payment details',
    'Connecting to payment gateway',
    'Processing transaction',
    'Generating your ticket',
    'Creating QR code',
    'Preparing verification code',
    'Setting ticket validity',
    'Almost there',
    'Finalizing your booking',
  ];

  int _currentIndex = 0;
  final List<int> _completedIndices = [];
  Timer? _phraseTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Advance phrases every 1.2 seconds
    _phraseTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _completedIndices.add(_currentIndex);
        _currentIndex = (_currentIndex + 1) % _phrases.length;
      });
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _pulseController.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0B1A2E),
              Color(0xFF132F54),
              Color(0xFF1565C0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated bus icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.1);
                  final glow = _pulseController.value * 0.5;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withOpacity(glow),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Scrolling phrases
              SizedBox(
                height: 220,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.15, 0.85, 1.0],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    itemCount: _phrases.length,
                    itemBuilder: (context, index) {
                      final isCompleted = _completedIndices.contains(index);
                      final isCurrent = index == _currentIndex;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            // Checkmark / spinner
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: isCompleted
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E)
                                            .withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Color(0xFF22C55E),
                                      ),
                                    )
                                  : isCurrent
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white70,
                                          ),
                                        )
                                      : Icon(
                                          Icons.circle_outlined,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                            ),
                            const SizedBox(width: 14),
                            // Phrase text
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                fontSize: isCurrent ? 16 : 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isCompleted
                                    ? const Color(0xFF22C55E).withOpacity(0.8)
                                    : isCurrent
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                              ),
                              child: Text('${_phrases[index]}...'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final progress = _completedIndices.length / _phrases.length;
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: const Color(0xFF42A5F5),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_completedIndices.length * 100 / _phrases.length).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Footer
              Text(
                'BUSGO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.3),
                  letterSpacing: 4,
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}










