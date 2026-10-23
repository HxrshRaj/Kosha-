import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A change pushed by the backend's `WS /ws/events` after a successful write.
class LiveChange {
  final String resource;
  final String method;
  const LiveChange(this.resource, this.method);
}

/// Opens the socket and returns its message stream. Injectable so tests do
/// not need a real server.
typedef SocketConnector = Future<Stream<dynamic>> Function(Uri uri);

Future<Stream<dynamic>> _defaultConnector(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel.stream;
}

/// Listens to the backend change feed and reconnects with capped backoff.
class LiveUpdatesService {
  final Uri uri;
  final SocketConnector _connect;
  final Duration baseDelay;
  final Duration maxDelay;

  LiveUpdatesService({
    required String baseUrl,
    SocketConnector? connector,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  }) : uri = wsUri(baseUrl),
       _connect = connector ?? _defaultConnector;

  /// http(s)://host -> ws(s)://host/ws/events
  static Uri wsUri(String baseUrl) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/events',
    );
  }

  /// Returns null for pings and anything that is not a change event.
  static LiveChange? parse(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      if (data is Map && data['event'] == 'changed') {
        return LiveChange(
          (data['resource'] ?? '').toString(),
          (data['method'] ?? '').toString(),
        );
      }
    } catch (_) {}
    return null;
  }

  Duration backoff(int attempt) {
    final ms = baseDelay.inMilliseconds * (1 << (attempt.clamp(0, 10)));
    return Duration(milliseconds: ms.clamp(0, maxDelay.inMilliseconds));
  }

  Stream<LiveChange> changes() {
    late final StreamController<LiveChange> controller;
    StreamSubscription<dynamic>? sub;
    Timer? timer;
    var closed = false;
    var attempt = 0;

    void scheduleReconnect() {
      if (closed) return;
      final delay = backoff(attempt++);
      timer = Timer(delay, connect);
    }

    Future<void> connectImpl() async {
      if (closed) return;
      try {
        final stream = await _connect(uri);
        if (closed) return;
        attempt = 0;
        sub = stream.listen(
          (message) {
            final change = parse(message);
            if (change != null && !controller.isClosed) controller.add(change);
          },
          onError: (_) => scheduleReconnect(),
          onDone: scheduleReconnect,
          cancelOnError: true,
        );
      } catch (_) {
        scheduleReconnect();
      }
    }

    connect() => connectImpl();

    controller = StreamController<LiveChange>(
      onListen: connect,
      onCancel: () async {
        closed = true;
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return controller.stream;
  }
}
