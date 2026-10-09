import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/badges.dart';
import '../widgets/help_tip.dart';
import '../widgets/helpers.dart';
import '../widgets/responsive.dart';
import '../../theme/app_theme.dart';

class ServerControlCard extends StatelessWidget {
  const ServerControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    // Not rebuilt by request logs; only by the server state and port.
    final running = context.select<AppState, bool>(
      (a) => a.selectedProject != null && a.isRunning(a.selectedProject!.id),
    );
    context.select<AppState, (String?, int?)>(
      (a) => (a.selectedProject?.id, a.selectedProject?.port),
    );
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
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
              // Status and help take the room the port leaves (the text
              // shrinks only when there truly isn't enough).
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        running ? 'Server running' : 'Server stopped',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: running
                              ? AppTheme.success
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    HelpTip(
                      running
                          ? 'Every enabled endpoint in this project is answering '
                                'real HTTP requests. Edits to endpoints apply right '
                                'away, with no restart needed.'
                          : 'Nothing is listening yet. Start the server so apps can '
                                'call your endpoints.',
                      title: running ? 'Server running' : 'Server stopped',
                      example: 'curl $baseUrl/hello',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HelpHover(
                'The number after the host in the address. Each running '
                'project needs its own free port; change it in Project '
                'settings while the server is stopped.',
                title: 'Port',
                example: 'localhost:${project.port}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'port',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (running)
            HelpHover(
              'Click to copy. Your app calls this address followed by an '
              'endpoint path. Other devices need the addresses in Share and '
              'expose.',
              title: 'Base URL',
              example: '$baseUrl/users',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    copyToClipboard(context, baseUrl, label: 'Base URL copied'),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: isPhone(context) ? 48 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
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
                      Icon(
                        Icons.copy,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
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
                    : HelpHover(
                        'Starts answering requests for this project\'s '
                        'endpoints on port ${project.port}.',
                        title: 'Start server',
                        example: baseUrl,
                        child: FilledButton.icon(
                          onPressed: () => _start(context, app),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Start server'),
                        ),
                      ),
              ),
              if (running) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip:
                      'Restart server. Open connections are dropped, and a '
                      'public tunnel to this port is stopped.',
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
