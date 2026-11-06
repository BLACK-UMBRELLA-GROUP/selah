// Shared widget-capture machinery for DOC-SELAH-0020. All screen content comes
// from the real app widgets supplied by each feature's masters test.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/main.dart' show SelahApp;

const masterPhoneSize = Size(430, 932);
const masterPixelRatio = 3.0;
const masterSafeArea = EdgeInsets.only(top: 59, bottom: 34);

Future<void> loadSelahMasterFonts() async {
  final figtree = FontLoader('Figtree')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Figtree[wght].ttf').readAsBytesSync(),
        ),
      ),
    );
  final cormorant = FontLoader('Cormorant Garamond');
  for (final file in [
    'CormorantGaramond[wght].ttf',
    'CormorantGaramond-Italic[wght].ttf',
  ]) {
    cormorant.addFont(
      Future.value(
        ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
      ),
    );
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([figtree.load(), cormorant.load(), icons.load()]);
}

class MasterScreen {
  MasterScreen(this.pane, this.boundary);
  final Widget pane;
  final GlobalKey boundary;
}

class MasterCaptureHarness {
  // LOCK 11 recaptures every feature without overwriting earlier evidence.
  // The suffix records the app-wide member wording revision independently
  // of the feature's own design/build version.
  MasterCaptureHarness({required String feature, String version = 'V1'})
    : version = '${version}_WORDING_V1',
      featureRoot = Directory('../APP/APPROVED/$feature').absolute;

  final Directory featureRoot;
  final String version;

  Future<MasterScreen> mount(
    WidgetTester tester, {
    required Widget home,
  }) async {
    tester.view.devicePixelRatio = masterPixelRatio;
    tester.view.physicalSize = masterPhoneSize * masterPixelRatio;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    // Read the real app's theme and outer builder. Feature tests supply real
    // screens, and separately activate the real exact-bundle draft policy.
    await tester.pumpWidget(const SelahApp());
    await tester.pump();
    final production = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(production.theme!.brightness, Brightness.light);
    final boundary = GlobalKey(debugLabel: 'master-built-screen');
    final pane = RepaintBoundary(
      key: boundary,
      child: SizedBox.fromSize(
        size: masterPhoneSize,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: production.theme,
          scrollBehavior: production.scrollBehavior,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: masterPhoneSize,
              devicePixelRatio: masterPixelRatio,
              padding: masterSafeArea,
              viewPadding: masterSafeArea,
              viewInsets: EdgeInsets.zero,
              textScaler: TextScaler.noScaling,
              platformBrightness: Brightness.light,
              disableAnimations: true,
              accessibleNavigation: true,
            ),
            child: production.builder?.call(context, child) ?? child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpWidget(pane);
    await tester.pump();
    return MasterScreen(pane, boundary);
  }

  Future<void> _prepareImages(WidgetTester tester) async {
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    await tester.runAsync(() async {
      for (final widget in images) {
        var ready = false;
        Object? error;
        unawaited(
          precacheImage(
            widget.image,
            tester.element(find.byWidget(widget)),
            onError: (exception, _) => error = exception,
          ).then((_) => ready = true),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        // FileImage callbacks may belong to FakeAsync, while codecs/I/O need
        // the real event loop. Drive both until the actual first frame exists.
        while (!ready && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        expect(ready, isTrue, reason: 'First frame for ${widget.image}');
        expect(error, isNull, reason: 'Decode ${widget.image}');
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> _golden(
    WidgetTester tester,
    GlobalKey boundary,
    String filename,
  ) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: masterPixelRatio);
      try {
        expect(image.width, (render.size.width * masterPixelRatio).round());
        expect(image.height, (render.size.height * masterPixelRatio).round());
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await expectLater(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          matchesGoldenFile(
            File('${featureRoot.path}/BUILT/$version/$filename').uri,
          ),
        );
      } finally {
        image.dispose();
      }
    });
  }

  /// Extra evidence explicitly requested without a designer-supplied master.
  Future<void> captureBuild(
    WidgetTester tester,
    MasterScreen screen,
    String name,
  ) async {
    await _prepareImages(tester);
    expect(tester.getSize(find.byKey(screen.boundary)), masterPhoneSize);
    await _golden(tester, screen.boundary, '${name}__build.png');
  }

  Future<void> capture(
    WidgetTester tester,
    MasterScreen screen,
    String master, {
    File? masterFile,
  }) async {
    await _prepareImages(tester);
    expect(tester.getSize(find.byKey(screen.boundary)), masterPhoneSize);
    await _golden(tester, screen.boundary, '${master}__build.png');
    final comparison = GlobalKey(debugLabel: 'master-beside-build');
    tester.view.physicalSize = const Size(860, 932) * masterPixelRatio;
    // Keep the same real app subtree/state and original 430-pixel width.
    await tester.pumpWidget(
      RepaintBoundary(
        key: comparison,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox.fromSize(
                size: masterPhoneSize,
                child: Image.file(
                  masterFile ?? File('${featureRoot.path}/MASTERS/$master.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              screen.pane,
            ],
          ),
        ),
      ),
    );
    await _prepareImages(tester);
    expect(tester.getSize(find.byKey(comparison)), const Size(860, 932));
    await _golden(tester, comparison, '${master}__master_beside_build.png');
  }
}
