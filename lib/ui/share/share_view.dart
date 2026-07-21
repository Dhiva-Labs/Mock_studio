import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/tunnel_service.dart';
import '../../state/app_state.dart';
import '../widgets/helpers.dart';

/// The "Share & Expose" tab: reach the mock from the LAN (phones/emulators)
/// and, optionally, the public internet through a tunnel.
class ShareView extends StatelessWidget {
  const ShareView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final project = app.selectedProject!;
    final running = app.isRunning(project.id);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!running)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: HintCard(
              'Your server is stopped. Start it first — then these URLs will be reachable.',
              icon: Icons.info_outline,
            ),
          ),
        _LocalSection(port: project.port, running: running),
        const SizedBox(height: 20),
        _LanSection(
          addresses: app.lanAddresses,
          port: project.port,
          running: running,
        ),
        const SizedBox(height: 20),
        _TunnelSection(running: running, port: project.port),
      ],
    );
  }
}

class _SectionShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled
            ? () => copyToClipboard(context, url, label: 'Copied $url')
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy, size: 15, color: scheme.onSurfaceVariant),
            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addresses.isEmpty)
            Text(
              'No LAN address detected. Are you connected to a network?',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final addr in addresses) ...[
                        _UrlChip(url: 'http://$addr:$port', enabled: running),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Android emulator? Use http://10.0.2.2:$port to reach this machine.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (primary != null && running) ...[
                  const SizedBox(width: 20),
                  Column(
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
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TunnelSection extends StatelessWidget {
  final bool running;
  final int port;
  const _TunnelSection({required this.running, required this.port});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tunnel = app.tunnel;
    final scheme = Theme.of(context).colorScheme;

    return _SectionShell(
      icon: Icons.public,
      title: 'Public internet (tunnel)',
      subtitle: 'Get a public https URL — great for webhooks (Stripe, GitHub…)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<TunnelProvider>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: TunnelProvider.cloudflared,
                    label: Text('cloudflared'),
                    icon: Icon(Icons.cloud_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: TunnelProvider.ngrok,
                    label: Text('ngrok'),
                    icon: Icon(Icons.hub_outlined, size: 16),
                  ),
                ],
                selected: {tunnel.provider},
                onSelectionChanged: tunnel.status == TunnelStatus.running
                    ? null
                    : (s) => tunnel.provider = s.first,
              ),
              const Spacer(),
              _tunnelStatusPill(context, tunnel.status),
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
            FutureBuilder<bool>(
              future: TunnelService.isAvailable(tunnel.provider),
              builder: (context, snap) {
                final available = snap.data ?? false;
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 20, child: Text('Checking…'));
                }
                if (!available) {
                  return _NotInstalledHint(provider: tunnel.provider);
                }
                return FilledButton.icon(
                  onPressed: running
                      ? () => tunnel.start(tunnel.provider, port)
                      : null,
                  icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                  label: Text(
                    running ? 'Start public tunnel' : 'Start the server first',
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _tunnelStatusPill(BuildContext context, TunnelStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      TunnelStatus.running => (const Color(0xFF16A34A), 'Live'),
      TunnelStatus.starting => (const Color(0xFFD97706), 'Starting'),
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

class _NotInstalledHint extends StatelessWidget {
  final TunnelProvider provider;
  const _NotInstalledHint({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCf = provider == TunnelProvider.cloudflared;
    final name = isCf ? 'cloudflared' : 'ngrok';
    final install = isCf
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
