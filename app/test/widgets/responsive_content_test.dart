import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/widgets/responsive_content.dart';

void main() {
  Widget wrap() => MaterialApp(
        home: Scaffold(
          body: ResponsiveContent(
            child: Container(
              key: const Key('content'),
              width: double.infinity,
              color: Colors.red,
            ),
          ),
        ),
      );

  testWidgets('on a phone-width screen, content is not width-constrained', (tester) async {
    // iPhone SE-ish width, well under the 600dp breakpoint. Resizing the
    // test binding's view (not just wrapping a MediaQuery) is required —
    // MaterialApp derives its own MediaQuery from the real test window.
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    final contentSize = tester.getSize(find.byKey(const Key('content')));
    // Should fill the phone-width screen, not be capped to maxWidth.
    expect(contentSize.width, 375);
  });

  testWidgets('on a tablet-width screen, content is capped and centered', (tester) async {
    // iPad-ish width, well over the 600dp breakpoint.
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    final contentSize = tester.getSize(find.byKey(const Key('content')));
    expect(contentSize.width, 640); // default maxWidth in ResponsiveContent
    expect(contentSize.width, lessThan(1024));
  });
}
