import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:flutter_telegram_miniapp/flutter_telegram_miniapp.dart' as tma;
import '../widgets/global/global_logo_bar.dart';
import '../telegram_safe_area.dart';
import '../app/theme/app_theme.dart';
import '../telegram_webapp.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  void _handleBackButton() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  StreamSubscription<tma.BackButton>? _backButtonSubscription;

  double _getAdaptiveBottomPadding() {
    final service = TelegramSafeAreaService();
    final safeAreaInset = service.getSafeAreaInset();
    final bottomPadding = safeAreaInset.bottom + 30;
    return bottomPadding;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final webApp = tma.WebApp();
        final eventHandler = webApp.eventHandler;

        _backButtonSubscription =
            eventHandler.backButtonClicked.listen((backButton) {
          print('[SendPage] Back button clicked!');
          _handleBackButton();
        });

        print('[SendPage] Back button listener registered');

        try {
          final telegramWebApp = TelegramWebApp();
          telegramWebApp.onBackButtonClick(() {
            print('[SendPage] Back button clicked (fallback)!');
            _handleBackButton();
          });
          print('[SendPage] Fallback back button listener registered');
        } catch (e) {
          print('[SendPage] Error setting up fallback back button: $e');
        }

        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            if (mounted) {
              webApp.backButton.show();
              print('[SendPage] Back button shown');
            }
          } catch (e) {
            print('[SendPage] Error showing back button: $e');
          }
        });
      } catch (e) {
        print('[SendPage] Error setting up back button: $e');
      }
    });
  }

  @override
  void dispose() {
    _backButtonSubscription?.cancel();

    try {
      tma.WebApp().backButton.hide();
    } catch (e) {
      // Ignore errors
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: GlobalLogoBar.fullscreenNotifier,
          builder: (context, isFullscreen, child) {
            final topPadding = GlobalLogoBar.getContentTopPadding();
            return Padding(
              padding: EdgeInsets.only(
                bottom: _getAdaptiveBottomPadding(),
                top: topPadding,
                left: 15,
                right: 15,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 570),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
