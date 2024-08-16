import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'reactive_block_ref.dart';

abstract class ObxWidget extends StatefulWidget {
  const ObxWidget({super.key});

  @override
  State<StatefulWidget> createState() => _ObxState();

  Widget build(BuildContext context, ReactiveBlockRef ref);
}

class _ObxState extends State<ObxWidget> implements ReactiveBlockRef {
  @override
  Widget build(BuildContext context) {
    return widget.build(context, this);
  }

  void _updateTree() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  T watch<T>(ValueListenable<T> observable) {
    if (!_subscriptions.contains(observable)) {
      observable.addListener(_updateTree);
      _subscriptions.add(observable);
    }
    return observable.value;
  }

  @override
  T watchListenable<T extends Listenable>(T listenable) {
    if (!_subscriptions.contains(listenable)) {
      listenable.addListener(_updateTree);
      _subscriptions.add(listenable);
    }
    return listenable;
  }

  @override
  ActionState watchAction(Future<void> Function() action) {
    final actionInternalState = _runningActions[action];

    if (actionInternalState == null || actionInternalState.isRunning) {
      return ActionState(isRunning: true, run: _noAction);
    }

    return ActionState(
      isRunning: false,
      error: actionInternalState.error,
      stackTrace: actionInternalState.stackTrace,
      run: () async {
        _runningActions[action] = const _ActionInternalState(isRunning: true, error: null);
        _updateTree();
        try {
          await action();
          _runningActions.remove(action);
          _updateTree();
        } catch (e, s) {
          _runningActions[action] = _ActionInternalState(isRunning: false, error: e, stackTrace: s);
          _updateTree();
        }
      },
    );
  }

  @override
  AsyncSnapshot<T> watchFuture<T>(Future<T> future, {T? initialData}) {
    final futureResult = _runningFutures[future];
    if (futureResult != null) {
      return futureResult as AsyncSnapshot<T>;
    }

    _runningFutures[future] =
        initialData != null ? AsyncSnapshot<T>.withData(ConnectionState.none, initialData) : AsyncSnapshot<T>.waiting();

    future.then<void>((T data) {
      _runningFutures[future] = AsyncSnapshot<T>.withData(ConnectionState.done, data);
      _updateTree();
    }, onError: (Object error, StackTrace stackTrace) {
      _runningFutures[future] = AsyncSnapshot<T>.withError(ConnectionState.done, error, stackTrace);
      _updateTree();
    });

    return _runningFutures[future] as AsyncSnapshot<T>;
  }

  @override
  AsyncSnapshot<T> watchStream<T>(Stream<T> stream, {T? initialData}) {
    final streamResult = _runningStreams[stream];
    if (streamResult != null) {
      return streamResult as AsyncSnapshot<T>;
    }

    _runningStreams[stream] =
        initialData != null ? AsyncSnapshot<T>.withData(ConnectionState.none, initialData) : AsyncSnapshot<T>.waiting();
    final sub = stream.listen((T data) {
      _runningStreams[stream] = AsyncSnapshot<T>.withData(ConnectionState.active, data);
      _updateTree();
    }, onError: (Object error, StackTrace stackTrace) {
      _runningStreams[stream] = AsyncSnapshot<T>.withError(ConnectionState.active, error, stackTrace);
      _updateTree();
    }, onDone: () {
      _runningStreams[stream] = _runningStreams[stream]!.inState(ConnectionState.done);
      _updateTree();
    });

    _streamSubscriptions.add(sub);

    return _runningStreams[stream] as AsyncSnapshot<T>;
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.removeListener(_updateTree);
    }

    for (var sub in _streamSubscriptions) {
      sub.cancel();
    }

    super.dispose();
  }

  final _subscriptions = <Listenable>{};
  final _runningActions = <Function, _ActionInternalState>{};

  final _runningFutures = <Future, AsyncSnapshot>{};
  final _runningStreams = <Stream, AsyncSnapshot>{};
  final _streamSubscriptions = <StreamSubscription>{};
}

class Obx extends ObxWidget {
  final Widget Function(ReactiveBlockRef ref) _builder;

  const Obx(this._builder, {super.key});

  @override
  Widget build(BuildContext context, ReactiveBlockRef ref) => _builder(ref);
}

void _noAction() {}

class _ActionInternalState {
  final bool isRunning;
  final Object? error;
  final StackTrace? stackTrace;

  const _ActionInternalState({
    required this.isRunning,
    this.error,
    this.stackTrace,
  });
}
