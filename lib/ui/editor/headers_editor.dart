import 'package:flutter/material.dart';

import '../widgets/help_tip.dart';

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

  /// One stable key per row, so deleting a row doesn't shift the typed text
  /// of the rows below into the wrong fields.
  late List<Key> _keys;

  @override
  void initState() {
    super.initState();
    _pairs = widget.headers.entries.toList();
    _keys = [for (final _ in _pairs) UniqueKey()];
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'RESPONSE HEADERS',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const HelpTip(
                      'Extra HTTP headers sent with this response. '
                      'Content-Type is set from the body type unless you add '
                      'your own.',
                      title: 'Response headers',
                      example: 'Cache-Control: no-store',
                      size: 14,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _pairs.add(const MapEntry('', ''));
                    _keys.add(UniqueKey());
                  });
                  widget.onMutated();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add header'),
              ),
            ],
          ),
        ),
        if (_pairs.isEmpty)
          Text(
            'Content-Type is set automatically. Add custom headers if needed.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ..._pairs.asMap().entries.map((entry) {
          final i = entry.key;
          final name = HelpHover(
            'The header to send. Names are not case-sensitive.',
            title: 'Header name',
            example: 'X-Request-Id',
            child: TextFormField(
              initialValue: entry.value.key,
              decoration: const InputDecoration(
                hintText: 'Header name',
                isDense: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              onChanged: (v) {
                _pairs[i] = MapEntry(v, _pairs[i].value);
                _sync();
              },
            ),
          );
          final value = HelpHover(
            'The header value. It can use placeholders that are filled in '
            'for each request.',
            title: 'Header value',
            example: '{{uuid}}',
            child: TextFormField(
              initialValue: entry.value.value,
              decoration: const InputDecoration(
                hintText: 'Value',
                isDense: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              onChanged: (v) {
                _pairs[i] = MapEntry(_pairs[i].key, v);
                _sync();
              },
            ),
          );
          final remove = IconButton(
            tooltip: 'Remove header',
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _pairs.removeAt(i);
                _keys.removeAt(i);
              });
              _sync();
              widget.onMutated();
            },
          );
          return Padding(
            key: _keys[i],
            padding: const EdgeInsets.only(bottom: 8),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 400
                  ? Row(
                      children: [
                        Expanded(flex: 2, child: name),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: value),
                        remove,
                      ],
                    )
                  // Narrow: name and remove button above, value below.
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: name),
                            remove,
                          ],
                        ),
                        const SizedBox(height: 6),
                        value,
                      ],
                    ),
            ),
          );
        }),
      ],
    );
  }
}
