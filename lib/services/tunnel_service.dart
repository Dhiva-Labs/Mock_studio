import 'dart:async';
import 'dart:io';

enum TunnelProvider { cloudflared, ngrok }

enum TunnelStatus { stopped, starting, running, error }

/// Manages a public tunnel by shelling out to `cloudflared` or `ngrok`.
///
/// cloudflared quick tunnels need no account and print a
/// `https://<random>.trycloudflare.com` URL to stderr. ngrok needs an authtoken
/// configured once (`ngrok config add-authtoken ...`) and exposes the URL via
/// its local API at http://127.0.0.1:4040/api/tunnels.
class TunnelService {
  Process? _process;
  TunnelStatus status = TunnelStatus.stopped;
  String? publicUrl;
  String? lastError;
  TunnelProvider provider = TunnelProvider.cloudflared;

  final _statusController = StreamController<void>.broadcast();
  final _logController = StreamController<String>.broadcast();

  Stream<void> get onChange => _statusController.stream;
  Stream<String> get onLog => _logController.stream;

  static final _cfUrl = RegExp(r'https://[a-z0-9-]+\.trycloudflare\.com');

  /// Checks whether the given provider's binary is on PATH.
  static Future<bool> isAvailable(TunnelProvider provider) async {
    final bin = provider == TunnelProvider.cloudflared
        ? 'cloudflared'
        : 'ngrok';
    try {
      final r = await Process.run('which', [bin]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> start(TunnelProvider provider, int port) async {
    if (status == TunnelStatus.running || status == TunnelStatus.starting) {
      return;
    }
    this.provider = provider;
    status = TunnelStatus.starting;
    publicUrl = null;
    lastError = null;
    _statusController.add(null);

    try {
      if (provider == TunnelProvider.cloudflared) {
        await _startCloudflared(port);
      } else {
        await _startNgrok(port);
      }
    } catch (e) {
      status = TunnelStatus.error;
      lastError = e.toString();
      _statusController.add(null);
    }
  }

  Future<void> _startCloudflared(int port) async {
    _process = await Process.start('cloudflared', [
      'tunnel',
      '--url',
      'http://localhost:$port',
      '--no-autoupdate',
    ]);
    _pipe(_process!.stdout);
    _pipe(_process!.stderr);
    _process!.exitCode.then((code) {
      if (status != TunnelStatus.stopped) {
        status = TunnelStatus.error;
        lastError = 'cloudflared exited (code $code)';
        _statusController.add(null);
      }
    });
  }

  Future<void> _startNgrok(int port) async {
    _process = await Process.start('ngrok', [
      'http',
      '$port',
      '--log',
      'stdout',
    ]);
    _pipe(_process!.stdout);
    _pipe(_process!.stderr);
    // Poll ngrok's local API for the public URL.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final url = await _queryNgrokApi();
      if (url != null) {
        publicUrl = url;
        status = TunnelStatus.running;
        _statusController.add(null);
        return;
      }
    }
    throw Exception(
      'ngrok did not report a public URL. Is your authtoken set?',
    );
  }

  Future<String?> _queryNgrokApi() async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:4040/api/tunnels'),
      );
      final res = await req.close();
      final body = await res.transform(const SystemEncoding().decoder).join();
      client.close();
      final match = RegExp(r'"public_url":"(https://[^"]+)"').firstMatch(body);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  void _pipe(Stream<List<int>> stream) {
    stream.transform(const SystemEncoding().decoder).listen((chunk) {
      _logController.add(chunk);
      if (provider == TunnelProvider.cloudflared && publicUrl == null) {
        final m = _cfUrl.firstMatch(chunk);
        if (m != null) {
          publicUrl = m.group(0);
          status = TunnelStatus.running;
          _statusController.add(null);
        }
      }
    });
  }

  Future<void> stop() async {
    status = TunnelStatus.stopped;
    publicUrl = null;
    _process?.kill();
    _process = null;
    _statusController.add(null);
  }

  void dispose() {
    _process?.kill();
    _statusController.close();
    _logController.close();
  }
}
