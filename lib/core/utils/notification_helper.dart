import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum NotificationType { success, error, warning, info, telegram }

class NotificationHelper {
  NotificationHelper._();

  static Color _backgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF1B5E20); // deep green
      case NotificationType.error:
        return const Color(0xFFB71C1C); // deep red
      case NotificationType.warning:
        return const Color(0xFFE65100); // deep orange
      case NotificationType.info:
        return const Color(0xFF0D47A1); // deep blue
      case NotificationType.telegram:
        return const Color(0xFF0088CC); // Telegram blue
    }
  }

  static Color _accentColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF69F0AE); // light green
      case NotificationType.error:
        return const Color(0xFFFF8A80); // light red
      case NotificationType.warning:
        return const Color(0xFFFFD180); // light orange
      case NotificationType.info:
        return const Color(0xFF82B1FF); // light blue
      case NotificationType.telegram:
        return Colors.white; // White for Telegram icon
    }
  }

  static IconData _icon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.warning:
        return Icons.warning_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
      case NotificationType.telegram:
        return Icons.telegram;
    }
  }

  static void showTop(
    BuildContext context, {
    required String message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _CustomAnimatedToast(
        message: message,
        type: type,
        duration: duration,
        onFinished: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  static void showTopWithMessenger(
    ScaffoldMessengerState messenger, {
    required double screenHeight,
    required String message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 3),
  }) {
  }
}

class _CustomAnimatedToast extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onFinished;

  const _CustomAnimatedToast({
    required this.message,
    required this.type,
    required this.duration,
    required this.onFinished,
  });

  @override
  State<_CustomAnimatedToast> createState() => _CustomAnimatedToastState();
}

class _CustomAnimatedToastState extends State<_CustomAnimatedToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dropAnimation;
  late Animation<double> _expandAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _dropAnimation = Tween<double>(begin: -100.0, end: 60.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic)),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0, curve: Curves.easeIn)),
    );

    _startSequence();
  }

  void _startSequence() async {
    if (!mounted) return;
    await _controller.forward();
    await Future.delayed(widget.duration);
    if (!mounted) return;
    await _controller.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth - 48;
    const minWidth = 50.0;
    const height = 50.0;

    final bgColor = NotificationHelper._backgroundColor(widget.type);
    final accentColor = NotificationHelper._accentColor(widget.type);
    final iconData = NotificationHelper._icon(widget.type);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentWidth = minWidth + (_expandAnimation.value * (maxWidth - minWidth));

        return Positioned(
          top: _dropAnimation.value,
          left: (screenWidth - currentWidth) / 2,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: currentWidth,
              height: height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: 13,
                      top: 13,
                      child: Icon(iconData, color: accentColor, size: 24),
                    ),
                    Positioned(
                      left: 48,
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.message,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
