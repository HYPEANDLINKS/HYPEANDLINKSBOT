import 'dart:js' as js;
import 'dart:async';

/// Telegram WebApp service for initializing and interacting with Telegram Mini App
class TelegramWebApp {
  static final TelegramWebApp _instance = TelegramWebApp._internal();
  factory TelegramWebApp() => _instance;
  TelegramWebApp._internal();

  bool _isInitialized = false;
  js.JsObject? _webApp;

  /// Check if Telegram WebApp is available (object exists)
  /// Note: This returns true even in browser because the script is loaded
  /// Use isActuallyInTelegram() for proper detection
  bool get isAvailable {
    try {
      final telegram = js.context['Telegram'];
      if (telegram == null) return false;
      final webApp = telegram['WebApp'];
      return webApp != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if we're actually running in Telegram (not just that the script is loaded)
  /// In browser: platform is "unknown" OR no user exists
  /// In Telegram: platform is valid (ios/android/web/etc) AND user exists
  bool get isActuallyInTelegram {
    if (!isAvailable) {
      print('[TelegramWebApp] isActuallyInTelegram: false (not available)');
      return false;
    }
    
    try {
      final platformValue = platform;
      final userValue = user;
      final hasUser = userValue != null;
      
      // Most reliable check: In Telegram, there should be a user object with an ID
      // Also check that platform is not "unknown"
      // In browser: platform is "unknown" OR no user exists OR user has no ID
      final hasValidUser = hasUser && 
                          userValue.containsKey('id') &&
                          userValue['id'] != null;
      final isInTelegram = platformValue != null && 
                          platformValue != 'unknown' && 
                          hasValidUser;
      
      print('[TelegramWebApp] isActuallyInTelegram: platform="$platformValue", hasUser=$hasUser, hasValidUser=$hasValidUser, result=$isInTelegram');
      
      return isInTelegram;
    } catch (e) {
      // If we can't determine, assume browser (safer)
      print('[TelegramWebApp] isActuallyInTelegram: error=$e, returning false (browser)');
      return false;
    }
  }

  /// Get the WebApp instance
  js.JsObject? get webApp {
    if (_webApp != null) return _webApp;
    
    try {
      final telegram = js.context['Telegram'];
      if (telegram == null) return null;
      final webApp = telegram['WebApp'];
      if (webApp is js.JsObject) {
        _webApp = webApp;
        return _webApp;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Initialize the Telegram WebApp
  /// This should be called as early as possible in your app lifecycle
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!isAvailable) {
      print('Telegram WebApp is not available');
      return;
    }

    try {
      final app = webApp;
      if (app == null) {
        print('Failed to get WebApp instance');
        return;
      }

      // Call ready() to notify Telegram that the app is ready
      final ready = app['ready'];
      if (ready is js.JsFunction) {
        ready.apply([]);
        print('Telegram WebApp ready() called');
      }

      // Expand the app to full screen
      final expand = app['expand'];
      if (expand is js.JsFunction) {
        expand.apply([]);
        print('Telegram WebApp expand() called');
      }

      // Set header color to black to hide it (matches background)
      setHeaderColor('#000000');

      // Enable closing confirmation if needed
      final enableClosingConfirmation = app['enableClosingConfirmation'];
      if (enableClosingConfirmation is js.JsFunction) {
        // Uncomment if you want to enable closing confirmation
        // enableClosingConfirmation.apply([]);
      }

      // Disable vertical swipe (swipe to close)
      final setupSwipeBehavior = app['setupSwipeBehavior'];
      if (setupSwipeBehavior is js.JsFunction) {
        try {
          setupSwipeBehavior.apply([
            js.JsObject.jsify({
              'allow_vertical_swipe': false,
            })
          ]);
          print('Telegram WebApp swipe behavior disabled');
        } catch (e) {
          print('Error setting up swipe behavior: $e');
        }
      }

      _isInitialized = true;
      print('Telegram WebApp initialized successfully');
    } catch (e) {
      print('Error initializing Telegram WebApp: $e');
    }
  }

  /// Get the init data (user data and startup parameters)
  Map<String, dynamic>? get initData {
    try {
      final app = webApp;
      if (app == null) return null;

      final data = app['initData'];
      if (data == null) return null;

      if (data is String) {
        // Parse initData string (it's URL-encoded)
        final uri = Uri.splitQueryString(data);
        return uri.map((key, value) => MapEntry(key, value));
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the init data as a string
  String? get initDataString {
    try {
      final app = webApp;
      if (app == null) return null;

      final data = app['initData'];
      return data is String ? data : null;
    } catch (e) {
      return null;
    }
  }

  /// Get the user data
  Map<String, dynamic>? get user {
    try {
      final app = webApp;
      if (app == null) return null;

      final initDataUnsafe = app['initDataUnsafe'];
      if (initDataUnsafe == null) return null;

      if (initDataUnsafe is js.JsObject) {
        final userObj = initDataUnsafe['user'];
        if (userObj == null || userObj is! js.JsObject) return null;

        return {
          'id': userObj['id'],
          'first_name': userObj['first_name'],
          'last_name': userObj['last_name'],
          'username': userObj['username'],
          'language_code': userObj['language_code'],
          'is_premium': userObj['is_premium'],
          'allows_write_to_pm': userObj['allows_write_to_pm'],
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the platform (ios, android, web, etc.)
  String? get platform {
    try {
      final app = webApp;
      if (app == null) return null;

      final platform = app['platform'];
      return platform is String ? platform : null;
    } catch (e) {
      return null;
    }
  }

  /// Get the version of Telegram WebApp
  String? get version {
    try {
      final app = webApp;
      if (app == null) return null;

      final version = app['version'];
      return version is String ? version : null;
    } catch (e) {
      return null;
    }
  }

  /// Trigger haptic impact (only in TMA). Style: 'light', 'medium', 'heavy', 'rigid', 'soft'.
  void impactOccurred(String style) {
    if (!isActuallyInTelegram) return;
    try {
      final app = webApp;
      if (app == null) return;
      final haptic = app['HapticFeedback'];
      if (haptic is! js.JsObject) return;
      final fn = haptic['impactOccurred'];
      if (fn is js.JsFunction) fn.apply([style]);
    } catch (_) {}
  }

  /// Get the color scheme (light or dark)
  String? get colorScheme {
    try {
      final app = webApp;
      if (app == null) return null;

      final colorScheme = app['colorScheme'];
      return colorScheme is String ? colorScheme : null;
    } catch (e) {
      return null;
    }
  }

  /// Get isFullscreen status
  /// Returns true if the Mini App is in fullscreen mode, false otherwise
  /// Returns null if Telegram WebApp is not available
  bool? get isFullscreen {
    try {
      final app = webApp;
      if (app == null) return null;

      final isFullscreen = app['isFullscreen'];
      if (isFullscreen is bool) {
        return isFullscreen;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the theme params (colors)
  Map<String, dynamic>? get themeParams {
    try {
      final app = webApp;
      if (app == null) return null;

      final themeParams = app['themeParams'];
      if (themeParams == null) return null;

      if (themeParams is js.JsObject) {
        return {
          'bg_color': themeParams['bg_color'],
          'text_color': themeParams['text_color'],
          'hint_color': themeParams['hint_color'],
          'link_color': themeParams['link_color'],
          'button_color': themeParams['button_color'],
          'button_text_color': themeParams['button_text_color'],
          'secondary_bg_color': themeParams['secondary_bg_color'],
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Set the header color
  void setHeaderColor(String color) {
    try {
      final app = webApp;
      if (app == null) return;

      final setHeaderColor = app['setHeaderColor'];
      if (setHeaderColor is js.JsFunction) {
        setHeaderColor.apply([color]);
      }
    } catch (e) {
      print('Error setting header color: $e');
    }
  }

  /// Set the background color
  void setBackgroundColor(String color) {
    try {
      final app = webApp;
      if (app == null) return;

      final setBackgroundColor = app['setBackgroundColor'];
      if (setBackgroundColor is js.JsFunction) {
        setBackgroundColor.apply([color]);
      }
    } catch (e) {
      print('Error setting background color: $e');
    }
  }

  /// Show the main button
  void showMainButton() {
    try {
      final app = webApp;
      if (app == null) return;

      final mainButton = app['MainButton'];
      if (mainButton == null) return;

      if (mainButton is js.JsObject) {
        final show = mainButton['show'];
        if (show is js.JsFunction) {
          show.apply([]);
        }
      }
    } catch (e) {
      print('Error showing main button: $e');
    }
  }

  /// Hide the main button
  void hideMainButton() {
    try {
      final app = webApp;
      if (app == null) return;

      final mainButton = app['MainButton'];
      if (mainButton == null) return;

      if (mainButton is js.JsObject) {
        final hide = mainButton['hide'];
        if (hide is js.JsFunction) {
          hide.apply([]);
        }
      }
    } catch (e) {
      print('Error hiding main button: $e');
    }
  }

  /// Set main button text
  void setMainButtonText(String text) {
    try {
      final app = webApp;
      if (app == null) return;

      final mainButton = app['MainButton'];
      if (mainButton == null) return;

      if (mainButton is js.JsObject) {
        final setText = mainButton['setText'];
        if (setText is js.JsFunction) {
          setText.apply([text]);
        }
      }
    } catch (e) {
      print('Error setting main button text: $e');
    }
  }

  /// Set main button click callback
  void onMainButtonClick(Function() callback) {
    try {
      final app = webApp;
      if (app == null) return;

      final mainButton = app['MainButton'];
      if (mainButton == null) return;

      if (mainButton is js.JsObject) {
        final onClick = mainButton['onClick'];
        if (onClick is js.JsFunction) {
          onClick.apply([js.allowInterop(callback)]);
        }
      }
    } catch (e) {
      print('Error setting main button click handler: $e');
    }
  }

  /// Show the back button
  void showBackButton() {
    try {
      final app = webApp;
      if (app == null) return;

      final backButton = app['BackButton'];
      if (backButton == null) return;

      if (backButton is js.JsObject) {
        final show = backButton['show'];
        if (show is js.JsFunction) {
          show.apply([]);
        }
      }
    } catch (e) {
      print('Error showing back button: $e');
    }
  }

  /// Hide the back button
  void hideBackButton() {
    try {
      final app = webApp;
      if (app == null) return;

      final backButton = app['BackButton'];
      if (backButton == null) return;

      if (backButton is js.JsObject) {
        final hide = backButton['hide'];
        if (hide is js.JsFunction) {
          hide.apply([]);
        }
      }
    } catch (e) {
      print('Error hiding back button: $e');
    }
  }

  /// Set back button click callback
  void onBackButtonClick(Function() callback) {
    try {
      final app = webApp;
      if (app == null) return;

      final backButton = app['BackButton'];
      if (backButton == null) return;

      if (backButton is js.JsObject) {
        final onClick = backButton['onClick'];
        if (onClick is js.JsFunction) {
          onClick.apply([js.allowInterop(callback)]);
        }
      }
    } catch (e) {
      print('Error setting back button click handler: $e');
    }
  }

  /// Close the web app
  void close() {
    try {
      final app = webApp;
      if (app == null) return;

      final close = app['close'];
      if (close is js.JsFunction) {
        close.apply([]);
      }
    } catch (e) {
      print('Error closing web app: $e');
    }
  }

  /// Send data to the bot
  void sendData(String data) {
    try {
      final app = webApp;
      if (app == null) return;

      final sendData = app['sendData'];
      if (sendData is js.JsFunction) {
        sendData.apply([data]);
      }
    } catch (e) {
      print('Error sending data: $e');
    }
  }

  /// Enable closing confirmation
  void enableClosingConfirmation() {
    try {
      final app = webApp;
      if (app == null) return;

      final enableClosingConfirmation = app['enableClosingConfirmation'];
      if (enableClosingConfirmation is js.JsFunction) {
        enableClosingConfirmation.apply([]);
      }
    } catch (e) {
      print('Error enabling closing confirmation: $e');
    }
  }

  /// Disable closing confirmation
  void disableClosingConfirmation() {
    try {
      final app = webApp;
      if (app == null) return;

      final disableClosingConfirmation = app['disableClosingConfirmation'];
      if (disableClosingConfirmation is js.JsFunction) {
        disableClosingConfirmation.apply([]);
      }
    } catch (e) {
      print('Error disabling closing confirmation: $e');
    }
  }

  /// Listen to viewport changes
  void onViewportChanged(Function(js.JsObject) callback) {
    try {
      final app = webApp;
      if (app == null) return;

      final onEvent = app['onEvent'];
      if (onEvent is js.JsFunction) {
        onEvent.apply([
          'viewportChanged',
          js.allowInterop((dynamic data) {
            if (data is js.JsObject) {
              callback(data);
            }
          })
        ]);
      }
    } catch (e) {
      print('Error setting up viewport changed listener: $e');
    }
  }

  /// Listen to theme changes
  /// When themeChanged event fires, the WebApp object already has updated colorScheme and themeParams
  void onThemeChanged(Function() callback) {
    try {
      final app = webApp;
      if (app == null) {
        print('Cannot set up theme changed listener: WebApp is not available');
        return;
      }

      final onEvent = app['onEvent'];
      if (onEvent is js.JsFunction) {
        onEvent.apply([
          'themeChanged',
          js.allowInterop((_) {
            // When this callback fires, the WebApp object (this) already has the new theme
            // Force refresh the cached _webApp to ensure we read the latest values
            _webApp = null;
            print('Theme changed event fired in TelegramWebApp');
            callback();
          })
        ]);
        print('Theme changed listener registered successfully');
      } else {
        print('onEvent is not available in WebApp');
      }
    } catch (e) {
      print('Error setting up theme changed listener: $e');
    }
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'isAvailable': isAvailable,
      'isInitialized': _isInitialized,
      'platform': platform,
      'version': version,
      'colorScheme': colorScheme,
      'user': user,
      'themeParams': themeParams,
    };
  }
}

