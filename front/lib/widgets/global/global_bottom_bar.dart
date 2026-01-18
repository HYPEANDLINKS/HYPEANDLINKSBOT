import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../app/theme/app_theme.dart';
import '../../analytics.dart';
import '../../pages/new_page.dart';

// Global bottom bar widget that appears on all pages
class GlobalBottomBar extends StatefulWidget {
  const GlobalBottomBar({super.key});

  @override
  State<GlobalBottomBar> createState() => _GlobalBottomBarState();
}

class _GlobalBottomBarState extends State<GlobalBottomBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    _controller.addListener(() {
      if (_controller.text.contains('\n')) {
        final textWithoutNewline = _controller.text.replaceAll('\n', '');
        _controller.value = TextEditingValue(
          text: textWithoutNewline,
          selection: TextSelection.collapsed(offset: textWithoutNewline.length),
        );
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _navigateToNewPage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      VercelAnalytics.trackEvent('question_submitted', properties: {
        'question_length': text.length.toString(),
      });

      VercelAnalytics.trackPageView(path: '/response', title: 'Response');

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => NewPage(title: text),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ).then((_) {
        _controller.clear();
        VercelAnalytics.trackPageView(path: '/', title: 'Home');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: AppTheme.backgroundColor,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 10, bottom: 15),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 30),
                    child: _controller.text.isEmpty
                      ? SizedBox(
                          height: 30,
                          child: TextField(
                            key: _textFieldKey,
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: true,
                            readOnly: false,
                            cursorColor: AppTheme.textColor,
                            cursorHeight: 15,
                            maxLines: 11,
                            minLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(
                                fontFamily: 'Aeroport',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 2.0,
                                color: AppTheme.textColor),
                            onSubmitted: (value) {
                              _navigateToNewPage();
                            },
                            onChanged: (value) {},
                            decoration: InputDecoration(
                              hintText: (_isFocused ||
                                      _controller.text.isNotEmpty)
                                  ? null
                                  : 'AI & Search',
                              hintStyle: TextStyle(
                                  color: AppTheme.textColor,
                                  fontFamily: 'Aeroport',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 2.0),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: !_isFocused
                                  ? const EdgeInsets.only(
                                      left: 0,
                                      right: 0,
                                      top: 5,
                                      bottom: 5)
                                  : const EdgeInsets.only(right: 0),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            key: _textFieldKey,
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: true,
                            readOnly: false,
                            cursorColor: AppTheme.textColor,
                            cursorHeight: 15,
                            maxLines: 11,
                            minLines: 1,
                            textAlignVertical: _controller.text
                                        .split('\n')
                                        .length ==
                                    1
                                ? TextAlignVertical.center
                                : TextAlignVertical.bottom,
                            style: TextStyle(
                                fontFamily: 'Aeroport',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 2,
                                color: AppTheme.textColor),
                            onSubmitted: (value) {
                              _navigateToNewPage();
                            },
                            onChanged: (value) {},
                            decoration: InputDecoration(
                              hintText: (_isFocused ||
                                      _controller.text.isNotEmpty)
                                  ? null
                                  : 'AI & Search',
                              hintStyle: TextStyle(
                                  color: AppTheme.textColor,
                                  fontFamily: 'Aeroport',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 2),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: _controller.text
                                          .split('\n')
                                          .length >
                                      1
                                  ? const EdgeInsets.only(
                                      left: 0, right: 0, top: 11)
                                  : const EdgeInsets.only(right: 0),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 7.5),
                child: GestureDetector(
                  onTap: () {
                    _navigateToNewPage();
                  },
                  child: SvgPicture.asset(
                    AppTheme.isLightTheme
                        ? 'assets/icons/apply_light.svg'
                        : 'assets/icons/apply_dark.svg',
                    width: 15,
                    height: 10,
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
      ),
    );
  }
}

