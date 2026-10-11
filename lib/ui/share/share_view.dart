import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/tunnel_service.dart';
import '../../state/app_state.dart';
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';
import '../../theme/app_theme.dart';

/// The "Share & Expose" tab: reach the mock from the LAN (phones/emulators)
/// and, optionally, the public internet through a tunnel.
class ShareView extends StatelessWidget {
  const ShareView({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the server state, port and addresses; logs don't rebuild this.
    final (_, port, running, lan) = context
        .select<AppState, (String?, int, bool, String)>((a) {
          final p = a.selectedProject!;
          return (p.id, p.port, a.isRunning(p.id), a.lanAddresses.join(','));
        });
    final app = context.read<AppState>();
    final project = app.selectedProject!;

    return ListView(
      padding: EdgeInsets.all(isPhone(context) ? 12 : 20),
      children: [
        // Always one slot (empty while running) so the sections below keep
        // their place in the list: otherwise starting the server rebuilt
        // them from scratch and the tunnel check showed "Checking…" again.
        running
            ? const SizedBox.shrink()
            : const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HintCard(
                  'Your server is stopped. Start it first — then these URLs '
                  'will be reachable.',
                  icon: Icons.info_outline,
                ),
              ),
        _LocalSection(port: port, running: running),
        const SizedBox(height: 20),
        _LanSection(
          addresses: lan.isEmpty ? const [] : lan.split(','),
          port: project.port,
          running: running,
        ),
        const SizedBox(height: 20),
        _TunnelSection(running: running, port: port),
      ],
    );
  }
}

class _SectionShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String help;
  final String? example;
  final Widget child;
  const _SectionShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.help,
    required this.child,
    this.example,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isPhone(context) ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabelWithHelp(
                        title,
                        help,
                        example: example,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _UrlChip extends StatelessWidget {
  final String url;
  final bool enabled;
  const _UrlChip({required this.url, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HelpHover(
      enabled
          ? 'Click to copy this address, then paste it into your app or '
                'browser.'
          : 'Start the server first; until then nothing answers here.',
      title: enabled ? 'Copy URL' : 'Server stopped',
      example: enabled ? '$url/users' : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled
              ? () => copyToClipboard(context, url, label: 'Copied $url')
              : null,
          child: Container(
            // 44 px or taller on phones.
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isPhone(context) ? 13 : 10,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    url,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy, size: 15, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalSection extends StatelessWidget {
  final int port;
  final bool running;
  const _LocalSection({required this.port, required this.running});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: Icons.computer_outlined,
      title: 'This computer',
      subtitle: 'For apps running on the same machine',
      help:
          'Use this address from a browser, curl or an app on this computer. '
          'localhost always means the device making the request, so a phone '
          'needs a LAN address instead.',
      example: 'curl http://localhost:$port/users',
      child: _UrlChip(url: 'http://localhost:$port', enabled: running),
    );
  }
}

class _LanSection extends StatelessWidget {
  final List<String> addresses;
  final int port;
  final bool running;
  const _LanSection({
    required this.addresses,
    required this.port,
    required this.running,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = addresses.isNotEmpty
        ? 'http://${addresses.first}:$port'
        : null;
    return _SectionShell(
      icon: Icons.wifi,
      title: 'Local network (LAN)',
      subtitle: 'For phones, emulators & teammates on the same Wi-Fi',
      help:
          'Devices on the same Wi-Fi or wired network can call your mock at '
          'these addresses. If a phone can\'t connect, check that your '
          'firewall allows port $port.',
      example: 'http://192.168.1.20:$port/users',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addresses.isEmpty)
            Text(
              'No LAN address detected. Are you connected to a network?',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final urls = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final addr in addresses) ...[
                      _UrlChip(url: 'http://$addr:$port', enabled: running),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    HelpHover(
                      '10.0.2.2 is the special address an Android emulator '
                      'uses to reach the computer it runs on.',
                      title: 'Android emulator',
                      example: 'http://10.0.2.2:$port/users',
                      child: Text(
                        'Android emulator? Use http://10.0.2.2:$port to '
                        'reach this machine.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
                if (primary == null || !running) return urls;
                final qr = HelpHover(
                  'Scan with your phone\'s camera to open the first LAN '
                  'address. The phone must be on the same network.',
                  title: 'QR code',
                  example: primary,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: QrImageView(
                          data: primary,
                          size: 120,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scan on your phone',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
                // Narrow: the QR code goes under the addresses.
                if (box.maxWidth < 440) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      urls,
                      const SizedBox(height: 12),
                      Center(child: qr),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: urls),
                    const SizedBox(width: 20),
                    qr,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TunnelSection extends StatefulWidget {
  final bool running;
  final int port;
  const _TunnelSection({required this.running, required this.port});

  @override
  State<_TunnelSection> createState() => _TunnelSectionState();
}

class _TunnelSectionState extends State<_TunnelSection> {
  @override
  Widget build(BuildContext context) {
    final running = widget.running;
    final port = widget.port;
    final app = context.read<AppState>();
    // Rebuilt by tunnel changes only, not by request logs.
    context.select<AppState, (TunnelStatus, TunnelProvider, String?, String?)>(
      (a) => (
        a.tunnel.status,
        a.tunnel.provider,
        a.tunnel.publicUrl,
        a.tunnel.lastError,
      ),
    );
    final tunnel = app.tunnel;
    final scheme = Theme.of(context).colorScheme;

    return _SectionShell(
      icon: Icons.public,
      title: 'Public internet (tunnel)',
      subtitle: 'Get a public https URL — great for webhooks (Stripe, GitHub…)',
      help:
          'A tunnel gives your mock a temporary public https address. Anyone '
          'who has the URL can call your mock while the tunnel runs, so keep '
          'real secrets out of your responses.',
      example: 'https://calm-river-12.trycloudflare.com/webhooks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider choice and status; the status wraps under on phones.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              SegmentedButton<TunnelProvider>(
                segments: [
                  ButtonSegment(
                    value: TunnelProvider.cloudflared,
                    label: _providerHover(
                      TunnelProvider.cloudflared,
                      const Text('cloudflared'),
                    ),
                    icon: _providerHover(
                      TunnelProvider.cloudflared,
                      const Icon(Icons.cloud_outlined, size: 16),
                    ),
                  ),
                  ButtonSegment(
                    value: TunnelProvider.ngrok,
                    label: _providerHover(
                      TunnelProvider.ngrok,
                      const Text('ngrok'),
                    ),
                    icon: _providerHover(
                      TunnelProvider.ngrok,
                      const Icon(Icons.hub_outlined, size: 16),
                    ),
                  ),
                ],
                selected: {tunnel.provider},
                // The service doesn't notify for this, so rebuild here (the
                // choice used to show only after the next app change).
                onSelectionChanged: tunnel.status == TunnelStatus.running
                    ? null
                    : (s) => setState(() => tunnel.provider = s.first),
              ),
              _statusHover(
                tunnel.status,
                _tunnelStatusPill(context, tunnel.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tunnel.status == TunnelStatus.running &&
              tunnel.publicUrl != null) ...[
            _UrlChip(url: tunnel.publicUrl!),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => tunnel.stop(),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop tunnel'),
                ),
              ],
            ),
          ] else if (tunnel.status == TunnelStatus.starting) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Starting ${tunnel.provider == TunnelProvider.cloudflared ? 'cloudflared' : 'ngrok'}…',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ] else ...[
            if (tunnel.lastError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tunnel.lastError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            _TunnelStart(
              provider: tunnel.provider,
              running: running,
              port: port,
              onStart: () => tunnel.start(tunnel.provider, port),
            ),
          ],
        ],
      ),
    );
  }

  Widget _providerHover(TunnelProvider provider, Widget child) =>
      provider == TunnelProvider.cloudflared
      ? HelpHover(
          'Cloudflare\'s free quick tunnel. No account needed; you get a new '
          'random address each time. Must be installed on this computer. '
          'Stop the tunnel to switch.',
          title: 'cloudflared',
          example: 'https://calm-river-12.trycloudflare.com',
          child: child,
        )
      : HelpHover(
          'Needs an ngrok account and its authtoken set once in a terminal. '
          'Must be installed on this computer. Stop the tunnel to switch.',
          title: 'ngrok',
          example: 'ngrok config add-authtoken <token>',
          child: child,
        );

  Widget _statusHover(TunnelStatus status, Widget child) {
    final (title, message) = switch (status) {
      TunnelStatus.running => (
        'Live',
        'The public URL works. Anyone who has it can reach your mock.',
      ),
      TunnelStatus.starting => (
        'Starting',
        'Waiting for the tunnel program to report a public address.',
      ),
      TunnelStatus.error => (
        'Error',
        'The tunnel stopped or never started. The message below says why.',
      ),
      TunnelStatus.stopped => (
        'Offline',
        'No tunnel is running, so the mock is not reachable from the internet.',
      ),
    };
    return HelpHover(message, title: title, child: child);
  }

  Widget _tunnelStatusPill(BuildContext context, TunnelStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      TunnelStatus.running => (AppTheme.success, 'Live'),
      TunnelStatus.starting => (AppTheme.warning, 'Starting'),
      TunnelStatus.error => (scheme.error, 'Error'),
      TunnelStatus.stopped => (scheme.outline, 'Offline'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "Start public tunnel", or how to install the tool when it's missing.
///
/// Looking for the tool runs `which`; the answer is kept until the provider
/// changes. Asking again on every rebuild showed "Checking…" for a moment
/// each time anything in the app changed (every logged request), so the
/// button flickered and a process was started each time.
class _TunnelStart extends StatefulWidget {
  const _TunnelStart({
    required this.provider,
    required this.running,
    required this.port,
    required this.onStart,
  });

  final TunnelProvider provider;
  final bool running;
  final int port;
  final VoidCallback onStart;

  @override
  State<_TunnelStart> createState() => _TunnelStartState();
}

class _TunnelStartState extends State<_TunnelStart> {
  late Future<bool> _available = TunnelService.isAvailable(widget.provider);

  @override
  void didUpdateWidget(_TunnelStart old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) {
      _available = TunnelService.isAvailable(widget.provider);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _available,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SizedBox(height: 20, child: Text('Checking…'));
      }
      if (!(snap.data ?? false)) {
        return _NotInstalledHint(provider: widget.provider);
      }
      return HelpHover(
        'Runs the tunnel program on this computer and forwards its public '
        'URL to port ${widget.port}. One tunnel runs at a time, and stopping '
        'this server also stops it.',
        title: 'Start public tunnel',
        child: FilledButton.icon(
          onPressed: widget.running ? widget.onStart : null,
          icon: const Icon(Icons.rocket_launch_outlined, size: 18),
          label: Text(
            widget.running ? 'Start public tunnel' : 'Start the server first',
          ),
        ),
      );
    },
  );
}

class _NotInstalledHint extends StatelessWidget {
  final TunnelProvider provider;
  const _NotInstalledHint({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCf = provider == TunnelProvider.cloudflared;
    final name = isCf ? 'cloudflared' : 'ngrok';
    // A program installed while Mock Studio runs is not on its PATH yet,
    // so Windows users have to restart the app.
    final install = Platform.isWindows
        ? (isCf
              ? 'Install cloudflared, then restart Mock Studio.\n'
                    '• winget install --id Cloudflare.cloudflared, or\n'
                    '• download cloudflared-windows-amd64.exe from Cloudflare\'s GitHub releases, rename it cloudflared.exe and put it on your PATH'
              : 'Install ngrok, set your authtoken, then restart Mock Studio:\n'
                    '• Download from ngrok.com/download\n'
                    '• ngrok config add-authtoken <YOUR_TOKEN>')
        : isCf
        ? 'Install cloudflared, then reopen this tab.\n'
              '• Debian/Ubuntu: download the .deb from Cloudflare, or\n'
              '• curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared'
        : 'Install ngrok and set your authtoken:\n'
              '• Download from ngrok.com/download\n'
              '• ngrok config add-authtoken <YOUR_TOKEN>';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.download_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '$name is not installed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            install,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (isCf) ...[
            const SizedBox(height: 6),
            Text(
              'cloudflared quick tunnels need no account.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
