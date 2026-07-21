import 'package:flutter/material.dart';

import '../widgets/helpers.dart';

/// A compact key/value editor for response headers.
class HeadersEditor extends StatefulWidget {
  final Map<String, String> headers;
  final VoidCallback onChanged;
  final VoidCallback onMutated;
  const HeadersEditor({
    super.key,
    required this.headers,
    required this.onChanged,
    required this.onMutated,
  });

  @override
  State<HeadersEditor> createState() => _HeadersEditorState();
}

class _HeadersEditorState extends State<HeadersEditor> {
  // Work on an ordered list of pairs, syncing back to the map on change.
  late List<MapEntry<String, String>> _pairs;

  @override
  void initState() {
    super.initState();
    _pairs = widget.headers.entries.toList();
  }

  void _sync() {
    widget.headers
      ..clear()
      ..addEntries(_pairs.where((e) => e.key.trim().isNotEmpty));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Response headers',
          trailing: TextButton.icon(
            onPressed: () {
              setState(() => _pairs.add(const MapEntry('', '')));
              widget.onMutated();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add header'),
          ),
        ),
        if (_pairs.isEmpty)
          Text(
            'Content-Type is set automatically. Add custom headers if needed.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ..._pairs.asMap().entries.map((entry) {
          final i = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: entry.value.key,
                    decoration: const InputDecoration(
                      hintText: 'Header name',
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    onChanged: (v) {
                      _pairs[i] = MapEntry(v, _pairs[i].value);
                      _sync();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: entry.value.value,
                    decoration: const InputDecoration(
                      hintText: 'Value',
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    onChanged: (v) {
                      _pairs[i] = MapEntry(_pairs[i].key, v);
                      _sync();
                    },
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() => _pairs.removeAt(i));
                    _sync();
                    widget.onMutated();
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
