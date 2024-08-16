import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ActionState {
  final bool isRunning;
  final void Function() run;
  final Object? error;
  final StackTrace? stackTrace;

  void Function()? get nullWhenRunning => isRunning ? null : run;

  ActionState({required this.isRunning, required this.run, this.error, this.stackTrace});
}

abstract class ReactiveBlockRef {
  T watch<T>(ValueListenable<T> observable);

  T watchListenable<T extends Listenable>(T listenable);

  ActionState watchAction(Future<void> Function() action);

  AsyncSnapshot<T> watchFuture<T>(Future<T> future);

  AsyncSnapshot<T> watchStream<T>(Stream<T> stream);
}
