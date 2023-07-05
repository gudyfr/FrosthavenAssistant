import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/server.dart';
import 'package:frosthaven_assistant/services/network/web_server.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class AutoConnect {
  bool _networkInfoReady = false;

  set networkInfoReady(value) {
    _networkInfoReady = value;
    autoConnectIfReady();
  }

  bool _gameStateReady = false;

  set gameStateReady(value) {
    _gameStateReady = value;
    autoConnectIfReady();
  }

  void autoConnectIfReady() {
    if (!_gameStateReady) {
      return;
    }

    if (!_networkInfoReady) {
      return;
    }

    final server = getIt<Network>().server;
    final webServer = getIt<Network>().webServer;
    final settings = getIt<Settings>();

    if (settings.autoStartServers.value) {
      if (!settings.server.value) {
        server.startServer();
      }
      if (!settings.enableWebServer.value) {
        webServer.startServer();
      }
    }
  }
}
