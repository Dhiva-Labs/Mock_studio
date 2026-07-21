import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/badges.dart';
import '../widgets/helpers.dart';

class ServerControlCard extends StatelessWidget {
  const ServerControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
    final running = app.isRunning(project.id);
    final baseUrl = 'http://localhost:${project.port}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RunningDot(running),
              const SizedBox(width: 8),
              Text(
                running ? 'Server running' : 'Server stopped',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: running
                      ? const Color(0xFF16A34A)
                      : scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'port',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Text(
                ':${project.port}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (running)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  copyToClipboard(context, baseUrl, label: 'Base URL copied'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        baseUrl,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.copy, size: 14, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          if (running) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: running
                    ? OutlinedButton.icon(
                        onPressed: () => app.stopServer(project),
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Stop'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: () => _start(context, app),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Start server'),
                      ),
              ),
              if (running) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Restart',
                  onPressed: () async {
                    final err = await app.restartServer(project);
                    if (err != null && context.mounted) {
                      showToast(context, err, error: true);
                    }
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, AppState app) async {
    final err = await app.startServer(app.selectedProject!);
    if (err != null && context.mounted) {
      showToast(context, err, error: true);
    } else if (context.mounted) {
      showToast(context, 'Server started on port ${app.selectedProject!.port}');
    }
  }
}
