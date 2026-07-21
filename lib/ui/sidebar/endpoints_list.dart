import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/endpoint.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../dialogs/dialogs.dart';
import '../widgets/badges.dart';

class EndpointsList extends StatefulWidget {
  final VoidCallback onSelect;
  const EndpointsList({super.key, required this.onSelect});

  @override
  State<EndpointsList> createState() => _EndpointsListState();
}

class _EndpointsListState extends State<EndpointsList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final project = app.selectedProject!;
    final endpoints = project.endpoints.where((e) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.path.toLowerCase().contains(q) ||
          e.method.label.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text(
                'ENDPOINTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${project.endpoints.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'New endpoint',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 20),
                onPressed: () =>
                    newEndpointDialog(context, app, onCreated: widget.onSelect),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search endpoints…',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: endpoints.isEmpty
              ? _EmptyEndpoints(
                  hasAny: project.endpoints.isNotEmpty,
                  onNew: () => newEndpointDialog(
                    context,
                    app,
                    onCreated: widget.onSelect,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: endpoints.length,
                  itemBuilder: (context, i) => _EndpointTile(
                    endpoint: endpoints[i],
                    selected: app.selectedEndpointId == endpoints[i].id,
                    onTap: () {
                      app.selectEndpoint(endpoints[i].id);
                      widget.onSelect();
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _EndpointTile extends StatelessWidget {
  final Endpoint endpoint;
  final bool selected;
  final VoidCallback onTap;
  const _EndpointTile({
    required this.endpoint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Opacity(
            opacity: endpoint.enabled ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  MethodBadge(endpoint.method, compact: true, fontSize: 10),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          endpoint.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                        Text(
                          endpoint.normalizedPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Endpoint actions',
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      switch (v) {
                        case 'toggle':
                          endpoint.enabled = !endpoint.enabled;
                          app.saveProject(app.selectedProject!);
                          break;
                        case 'duplicate':
                          app.duplicateEndpoint(app.selectedProject!, endpoint);
                          break;
                        case 'delete':
                          app.deleteEndpoint(app.selectedProject!, endpoint);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          leading: Icon(
                            endpoint.enabled
                                ? Icons.toggle_on
                                : Icons.toggle_off_outlined,
                          ),
                          title: Text(endpoint.enabled ? 'Disable' : 'Enable'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplicate'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyEndpoints extends StatelessWidget {
  final bool hasAny;
  final VoidCallback onNew;
  const _EmptyEndpoints({required this.hasAny, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAny ? Icons.search_off : Icons.api_outlined,
              size: 40,
              color: scheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasAny ? 'No matches' : 'No endpoints yet',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!hasAny) ...[
              const SizedBox(height: 6),
              Text(
                'Add your first endpoint to\nstart serving mock responses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New endpoint'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
