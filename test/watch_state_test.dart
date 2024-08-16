import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_state/src/obx.dart';

import 'package:watch_state/watch_state.dart';

class TestState {
  final testVal = ValueNotifier<String>("0");
  final Future<String> future;
  final Stream<String> stream;

  TestState({
    required this.future,
    required this.stream,
  });
}

class ValueNotifierWidget extends StatelessWidget {
  final ValueNotifier<String> state;

  const ValueNotifierWidget({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx((ref) => Column(
          children: [
            Text("watch:${ref.watch(state)}"),
          ],
        ));
  }
}

class FutureWidget extends StatelessWidget {
  final Future<String> state;
  final ValueNotifier<String> changesTrigger;

  const FutureWidget({Key? key, required this.state, required this.changesTrigger}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx((ref) {
      final asyncSnapshot = ref.watchFuture(state);
      ref.watch(changesTrigger);

      return Column(
        children: [
          if (asyncSnapshot.connectionState == ConnectionState.waiting) const Text("waiting"),
          if (asyncSnapshot.hasData) Text("data:${asyncSnapshot.data}"),
          if (asyncSnapshot.hasError) Text("error:${asyncSnapshot.error}"),
        ],
      );
    });
  }
}

class StreamWidget extends StatelessWidget {
  final Stream<String> state;
  final ValueNotifier<String> changesTrigger;

  const StreamWidget({Key? key, required this.state, required this.changesTrigger}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx((ref) {
      final asyncSnapshot = ref.watchStream(state);
      ref.watch(changesTrigger);

      return Column(
        children: [
          if (asyncSnapshot.connectionState == ConnectionState.waiting) const Text("waiting"),
          if (asyncSnapshot.hasData) Text("data:${asyncSnapshot.data}"),
          if (asyncSnapshot.hasError) Text("error:${asyncSnapshot.error}"),
        ],
      );
    });
  }
}

class TestingWidget extends StatelessWidget {
  final TestState state;

  const TestingWidget({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx((ref) => Column(
          children: [
            Text("watch:${ref.watch(state.testVal)}"),
            Text("future:${ref.watchFuture(state.future)}"),
            Text("stream:${ref.watchStream(state.stream)}"),
          ],
        ));
  }
}

void main() {
  testWidgets('Test watch', (WidgetTester tester) async {
    final testVal = ValueNotifier<String>("0");
    await tester.pumpWidget(MaterialApp(home: ValueNotifierWidget(state: testVal)));

    expect(find.text("watch:0"), findsOneWidget);
    expect(find.text("watch:1"), findsNothing);

    testVal.value = "1";
    await tester.pump();

    expect(find.text("watch:0"), findsNothing);
    expect(find.text("watch:1"), findsOneWidget);
  });

  testWidgets('Test watchFuture', (WidgetTester tester) async {
    final completer = Completer<String>();
    final changesTrigger = ValueNotifier<String>("0");

    await tester.pumpWidget(MaterialApp(home: FutureWidget(state: completer.future, changesTrigger: changesTrigger)));

    expect(find.text("waiting"), findsOneWidget);
    expect(find.text("data:data"), findsNothing);
    expect(find.text("error:null"), findsNothing);

    completer.complete("data");
    await tester.pump();

    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data"), findsOneWidget);
    expect(find.text("error:null"), findsNothing);

    changesTrigger.value = "1";
    await tester.pump();

    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data"), findsOneWidget);
    expect(find.text("error:null"), findsNothing);
  });

  testWidgets('Test watchFuture error', (WidgetTester tester) async {
    final completer = Completer<String>();
    final changesTrigger = ValueNotifier<String>("0");

    await tester.pumpWidget(MaterialApp(home: FutureWidget(state: completer.future, changesTrigger: changesTrigger)));

    expect(find.text("waiting"), findsOneWidget);
    expect(find.text("data:data"), findsNothing);
    expect(find.text("error:null"), findsNothing);

    completer.completeError("error");
    await tester.pump();

    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data"), findsNothing);
    expect(find.text("error:error"), findsOneWidget);

    changesTrigger.value = "1";
    await tester.pump();
    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data"), findsNothing);
    expect(find.text("error:error"), findsOneWidget);
  });

  testWidgets('Test watchStream', (WidgetTester tester) async {
    final controller = StreamController<String>();
    final changesTrigger = ValueNotifier<String>("0");

    await tester.pumpWidget(MaterialApp(home: StreamWidget(state: controller.stream, changesTrigger: changesTrigger)));

    expect(find.text("waiting"), findsOneWidget);
    expect(find.text("data:data"), findsNothing);
    expect(find.text("error:null"), findsNothing);

    controller.add("data");
    await tester.pump();

    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data"), findsOneWidget);
    expect(find.text("error:null"), findsNothing);

    changesTrigger.value = "1";
    await tester.pump();

    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data"), findsOneWidget);
    expect(find.text("error:null"), findsNothing);

    controller.add("data2");
    await tester.pump();
    await tester.pump();

    expect(find.text("waiting"), findsNothing);
    expect(find.text("data:data2"), findsOneWidget);
    expect(find.text("error:null"), findsNothing);
  });
}
