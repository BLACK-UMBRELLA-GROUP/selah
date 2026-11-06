import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/widgets/selah_switch.dart';

void main() {
  testWidgets('locked switch paints a 46 by 28 lake/line track and toggles', (
    tester,
  ) async {
    var value = false;
    var enabled = true;
    var calls = 0;
    late StateSetter update;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: ColoredBox(
                    color: Colors.white,
                    child: SizedBox(
                      width: 100,
                      height: 80,
                      child: Center(
                        child: SelahSwitch(
                          value: value,
                          onChanged: enabled
                              ? (next) => setState(() {
                                  value = next;
                                  calls++;
                                })
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SelahSwitch)), const Size(46, 28));

    Future<void> expectTrack(int red, int green, int blue) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final bytes = data.buffer.asUint8List();
        var left = image.width;
        var right = -1;
        var top = image.height;
        var bottom = -1;
        var exactColor = false;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final index = (y * image.width + x) * 4;
            final r = bytes[index];
            final g = bytes[index + 1];
            final b = bytes[index + 2];
            if (r != 255 || g != 255 || b != 255) {
              if (x < left) left = x;
              if (x > right) right = x;
              if (y < top) top = y;
              if (y > bottom) bottom = y;
            }
            exactColor |= r == red && g == green && b == blue;
          }
        }
        image.dispose();
        expect(
          Size((right - left + 1).toDouble(), (bottom - top + 1).toDouble()),
          const Size(46, 28),
        );
        expect(exactColor, isTrue);
      });
    }

    await expectTrack(0xD5, 0xDC, 0xDC);
    await tester.tap(find.byType(SelahSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(calls, 1);
    await expectTrack(0x3E, 0x6B, 0x78);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SelahSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(calls, 1);
  });

  testWidgets('list-tile label toggles once and respects disabled state', (
    tester,
  ) async {
    var value = false;
    var enabled = true;
    var calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SelahSwitchListTile(
                title: const Text('Share this answer'),
                subtitle: const Text('Existing choice'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: value,
                onChanged: enabled
                    ? (next) => setState(() {
                        value = next;
                        calls++;
                      })
                    : null,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share this answer'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(calls, 1);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share this answer'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(calls, 1);
  });
}
