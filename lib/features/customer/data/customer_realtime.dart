import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../core/network/api_client.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';

class SignalRCustomerRealtime implements CustomerRealtime {
  SignalRCustomerRealtime(this.api);
  final ApiClient api;
  HubConnection? _hub;
  final _events = StreamController<CustomerRealtimeEvent>.broadcast();
  bool _closed = false;
  Timer? _retry;
  bool _connecting = false;
  @override
  Stream<CustomerRealtimeEvent> get events => _events.stream;
  @override
  Future<void> start(int orderId) async {
    if (_closed) return;
    final hub = HubConnectionBuilder()
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
    _hub = hub;
    void changed(List<Object?>? _) {
      if (!_closed) _events.add(const CustomerRealtimeEvent());
    }

    hub.on('OrderStatusChanged', changed);
    hub.on('NotificationReceived', changed);
    hub.on('LocationUpdated', (args) {
      if (_closed || args == null || args.isEmpty || args.first is! Map) return;
      final j = Map<String, dynamic>.from(args.first as Map);
      if ('${j['orderId']}' != '$orderId') return;
      final lat = j['latitude'],
          lng = j['longitude'],
          at = DateTime.tryParse('${j['at']}');
      if (lat is num && lng is num && at != null) {
        _events.add(
          CustomerRealtimeEvent(
            position: GeoPosition(lat.toDouble(), lng.toDouble()),
            at: at,
          ),
        );
      }
    });
    hub.onreconnected(({connectionId}) async {
      if (_closed) return;
      try {
        await hub.invoke('JoinOrder', args: [orderId]);
        if (!_closed) {
          _events.add(const CustomerRealtimeEvent(reconnected: true));
        }
      } catch (_) {
        changed(null);
      }
    });
    Future<void> connect() async {
      if (_closed || _connecting) return;
      _connecting = true;
      try {
        if (hub.state == HubConnectionState.Disconnected) await hub.start();
        if (_closed) {
          await hub.stop();
          return;
        }
        await hub.invoke('JoinOrder', args: [orderId]);
        if (!_closed) {
          _events.add(const CustomerRealtimeEvent(reconnected: true));
        }
      } catch (_) {
        if (!_closed) {
          _retry?.cancel();
          _retry = Timer(const Duration(seconds: 5), connect);
        }
      } finally {
        _connecting = false;
      }
    }

    hub.onclose(({error}) {
      if (!_closed) {
        _retry?.cancel();
        _retry = Timer(const Duration(seconds: 5), connect);
      }
    });
    await connect();
  }

  @override
  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    _retry?.cancel();
    await _hub?.stop();
    await _events.close();
  }
}
