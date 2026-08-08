import 'package:flutter/material.dart';

enum TopNotificationType { success, warning, error, info }

class TopNotification {
  /// Toggle to enable or disable top floating notifications globally.
  /// Set to false by default as per user request.
  static bool enabled = false;

  static void show(
    BuildContext context, {
    required String message,
    TopNotificationType type = TopNotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!enabled) return;

    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case TopNotificationType.success:
        bgColor = const Color(0xFF1B5E20);
        iconColor = Colors.white;
        icon = Icons.check_circle_rounded;
        break;
      case TopNotificationType.warning:
        bgColor = const Color(0xFFE65100);
        iconColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case TopNotificationType.error:
        bgColor = const Color(0xFFB71C1C);
        iconColor = Colors.white;
        icon = Icons.error_outline_rounded;
        break;
      case TopNotificationType.info:
        bgColor = const Color(0xFF0D47A1);
        iconColor = Colors.white;
        icon = Icons.info_outline_rounded;
        break;
    }

    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: 25,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: -60, end: 0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: child,
                );
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: iconColor, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(entry);

    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: TopNotificationType.success);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, type: TopNotificationType.warning);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, type: TopNotificationType.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: TopNotificationType.info);
  }
}
