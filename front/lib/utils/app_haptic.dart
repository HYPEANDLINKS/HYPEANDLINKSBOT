import '../telegram_webapp.dart';

/// App-wide haptic feedback. Use this for all tap/impact vibrations in TMA.
/// Styles: 'light', 'medium', 'heavy', 'rigid', 'soft'.
/// No-op when not running inside Telegram Mini App.
class AppHaptic {
  AppHaptic._();

  /// Trigger impact haptic. Call from onTap/onPressed handlers.
  static void impact(String style) {
    TelegramWebApp().impactOccurred(style);
  }

  /// Convenience: heavy impact (e.g. navigation, primary actions).
  static void heavy() => impact('heavy');

  /// Convenience: rigid impact (e.g. secondary / no-navigation actions).
  static void rigid() => impact('rigid');

  /// Convenience: light impact (e.g. selection change).
  static void light() => impact('light');
}
