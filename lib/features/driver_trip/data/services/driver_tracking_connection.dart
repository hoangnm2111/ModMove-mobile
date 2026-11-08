import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/trip_models.dart';

abstract interface class DriverTrackingConnection {
  Stream<void> get updates;
  Future<void> send(GpsFix fix);
  Future<void> pause();
  Future<void> close();
}

class SignalRDriverTracking implements DriverTrackingConnection {
  SignalRDriverTracking(this.api) {
    _hub = HubConnectionBuilder()
        .withUrl(
          '${api.baseUrl}/hubs/tracking',
          options: HttpConnectionOptions(
            accessTokenFactory: api.accessToken,
            requestTimeout: 10000,
            logMessageContent: false,
          ),
        )
        .withAutomaticReconnect()
        .build();
    for (final event in ['OrderStatusChanged', 'NotificationReceived']) {
      _hub.on(event, (_) {
        if (!_updates.isClosed) _updates.add(null);
      });
    }
  }
  final ApiClient api;
  late final HubConnection _hub;
  final _updates = StreamController<void>.broadcast();
  @override
  Stream<void> get updates => _updates.stream;
  @override
  Future<void> send(GpsFix fix) async {
    try {
      if (_hub.state == HubConnectionState.Disconnected) await _hub.start();
      if (_hub.state != HubConnectionState.Connected) {
        throw StateError('reconnecting');
      }
      await _hub
          .invoke(
            'SendLocation',
            args: [fix.point.latitude, fix.point.longitude],
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Same authenticated command on REST when the WebSocket is reconnecting.
      await api.request(
        'POST',
        '/api/driver/location',
        body: {
          'latitude': fix.point.latitude,
          'longitude': fix.point.longitude,
        },
      );
    }
  }

  @override
  Future<void> pause() => _hub.stop();
  @override
  Future<void> close() async {
    await _hub.stop();
    await _updates.close();
  }
}
