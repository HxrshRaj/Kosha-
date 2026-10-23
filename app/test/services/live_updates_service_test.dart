import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kosha/services/live_updates_service.dart';

const _fast = Duration(milliseconds: 5);

void main() {
  test('wsUri maps http(s) to ws(s) and targets /ws/events', () {
    expect(LiveUpdatesService.wsUri('https://api.example.com').toString(),
        'wss://api.example.com/ws/events');
    expect(LiveUpdatesService.wsUri('http://10.0.2.2:8000').toString(),
        'ws://10.0.2.2:8000/ws/events');
  });

  test('parse keeps change events and drops pings and garbage', () {
    final c = LiveUpdatesService.parse(
        '{"event":"changed","resource":"transactions","method":"POST"}');
    expect(c?.resource, 'transactions');
    expect(c?.method, 'POST');
    expect(LiveUpdatesService.parse('{"event":"ping"}'), isNull);
    expect(LiveUpdatesService.parse('not json'), isNull);
    expect(LiveUpdatesService.parse(42), isNull);
  });

  test('backoff doubles and is capped', () {
    final s = LiveUpdatesService(
      baseUrl: 'http://x',
      connector: (_) async => const Stream.empty(),
      baseDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 8),
    );
    expect(s.backoff(0), const Duration(seconds: 1));
    expect(s.backoff(2), const Duration(seconds: 4));
    expect(s.backoff(10), const Duration(seconds: 8));
  });

  test('emits changes from the socket', () async {
    final socket = StreamController<dynamic>();
    final service = LiveUpdatesService(
      baseUrl: 'http://x',
      connector: (_) async => socket.stream,
      baseDelay: _fast,
    );
    final got = <LiveChange>[];
    final sub = service.changes().listen(got.add);
    await Future<void>.delayed(_fast * 2);
    socket.add('{"event":"ping"}');
    socket.add('{"event":"changed","resource":"categories","method":"POST"}');
    await Future<void>.delayed(_fast * 2);
    expect(got.map((c) => c.resource), ['categories']);
    await sub.cancel();
    await socket.close();
  });

  test('reconnects after the connection drops and after a failed connect', () async {
    var connects = 0;
    final controllers = <StreamController<dynamic>>[];
    final service = LiveUpdatesService(
      baseUrl: 'http://x',
      baseDelay: _fast,
      maxDelay: _fast,
      connector: (_) async {
        connects++;
        if (connects == 1) throw Exception('server asleep');
        final c = StreamController<dynamic>();
        controllers.add(c);
        return c.stream;
      },
    );
    final got = <LiveChange>[];
    final sub = service.changes().listen(got.add);
    await Future<void>.delayed(_fast * 6);
    expect(connects, 2, reason: 'retried after the first failure');

    await controllers.first.close(); // server drops the socket
    await Future<void>.delayed(_fast * 6);
    expect(connects, 3, reason: 'reconnected after the stream ended');

    controllers.last.add('{"event":"changed","resource":"transactions","method":"DELETE"}');
    await Future<void>.delayed(_fast * 2);
    expect(got.single.method, 'DELETE');
    await sub.cancel();
  });

  test('cancelling stops reconnect attempts', () async {
    var connects = 0;
    final service = LiveUpdatesService(
      baseUrl: 'http://x',
      baseDelay: _fast,
      maxDelay: _fast,
      connector: (_) async {
        connects++;
        throw Exception('down');
      },
    );
    final sub = service.changes().listen((_) {});
    await Future<void>.delayed(_fast * 4);
    await sub.cancel();
    final atCancel = connects;
    await Future<void>.delayed(_fast * 6);
    expect(connects, atCancel);
  });
}
