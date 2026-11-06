// LOCK 1: bundled Figtree reading text and Cormorant Garamond display roles.
import 'package:flutter/material.dart';
import 'selah_colors.dart';

enum SelahAppFont {
  figtree('Figtree', 'Figtree');

  final String label;
  final String family;
  const SelahAppFont(this.label, this.family);
}

class SelahText {
  SelahText._();
  static const currentDefaultFont = SelahAppFont.figtree;
  static final appFontSelection = ValueNotifier<SelahAppFont>(
    currentDefaultFont,
  );
  @visibleForTesting
  static bool useTestFontStubs = false;
  @visibleForTesting
  static String? testReadingFontFamily;
  @visibleForTesting
  static String? testWordmarkFontFamily;
  static SelahAppFont get appFont => currentDefaultFont;
  static void selectAppFont(SelahAppFont _) {
    appFontSelection.value = currentDefaultFont;
  }

  static void restoreAppFont(String? _) => selectAppFont(currentDefaultFont);
  static TextStyle _reading(
    double size,
    FontWeight weight,
    Color? color, {
    double? height,
    double? spacing,
  }) => TextStyle(
    fontFamily: testReadingFontFamily ?? 'Figtree',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
  static TextStyle preview(
    SelahAppFont font, {
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => _reading(size, weight, color ?? SelahColors.foreground);
  static TextTheme textTheme(TextTheme base) => base
      .apply(fontFamily: testReadingFontFamily ?? 'Figtree')
      .copyWith(
        bodyLarge: body(),
        bodyMedium: body(),
        bodySmall: subtext(),
        labelLarge: button(),
        titleLarge: pageTitle(),
      );
  static TextStyle heading({double size = 33.6, Color? color}) => TextStyle(
    fontFamily: testWordmarkFontFamily ?? 'Cormorant Garamond',
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color ?? SelahColors.foreground,
    height: 1.1,
  );
  static const pageTitleSize = 33.6;
  static TextStyle pageTitle() => heading();
  static TextStyle wordmark({double size = 36, Color? color}) =>
      heading(size: size, color: color).copyWith(letterSpacing: size * .02);
  static TextStyle quote() =>
      heading(size: 22.8).copyWith(fontStyle: FontStyle.italic, height: 1.35);
  static TextStyle memberName() => heading(size: 36).copyWith(height: 1);
  static TextStyle rowTitle() =>
      _reading(15, FontWeight.w600, SelahColors.inkColor);
  static TextStyle body({double size = 15, Color? color}) => _reading(
    size,
    FontWeight.w400,
    color ?? SelahColors.foregroundBody,
    height: 1.5,
  );
  static TextStyle subtext({double size = 13, Color? color}) =>
      _reading(size, FontWeight.w400, color ?? SelahColors.muted);
  static double taglineSize(BuildContext context) =>
      (MediaQuery.sizeOf(context).shortestSide.clamp(280.0, 480.0) * .0333)
          .clamp(12.5, 17.0);
  static TextStyle option({double size = 15, Color? color}) =>
      _reading(size, FontWeight.w600, color ?? SelahColors.foreground);
  static TextStyle button({double size = 15, Color? color}) =>
      _reading(size, FontWeight.w600, color);
  static TextStyle chapterLabel({Color? color}) =>
      _reading(11, FontWeight.w600, color ?? SelahColors.muted, spacing: 1.32);
  static TextStyle privacyText({Color? color}) =>
      _reading(11, FontWeight.w400, color ?? SelahColors.muted);
}

/// The locked wordmark keeps its breath mark independently coloured.
class SelahWordmark extends StatelessWidget {
  const SelahWordmark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: 'Selah',
      style: SelahText.wordmark(size: size),
      children: [
        TextSpan(
          text: '’',
          style: SelahText.wordmark(size: size * .9, color: SelahColors.dawn),
        ),
      ],
    ),
  );
}
