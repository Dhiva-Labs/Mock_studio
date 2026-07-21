import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/mock_response.dart';
import '../../services/template_engine.dart';
import '../../theme/app_theme.dart';
import 'body_editor.dart';
import 'conditions_editor.dart';
import 'headers_editor.dart';

/// An expandable editor for a single [MockResponse] variant.
class ResponseCard extends StatefulWidget {
  final MockResponse response;
  final int index;
  final bool showConditions;
  final bool showWeight;
  final bool showOrder;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const ResponseCard({
    super.key,
    required this.response,
    required this.index,
    required this.showConditions,
    required this.showWeight,
    required this.showOrder,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<ResponseCard> createState() => _ResponseCardState();
}

class _ResponseCardState extends State<ResponseCard> {
  late final TextEditingController _labelCtrl;
  late bool _expanded;

  MockResponse get r => widget.response;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: r.label);
    _expanded = widget.index == 0;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _changed(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = AppTheme.statusColor(r.statusCode);

    return Card(
      child: Column(
        children: [
          // Header row.
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  if (widget.showOrder)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  // Status code chip.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '${r.statusCode}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.label.isEmpty ? 'Response' : r.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r.fault != FaultType.none)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: 'Fault: ${r.fault.label}',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: scheme.error,
                        ),
                      ),
                    ),
                  if (widget.showWeight)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'weight ${r.weight}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (widget.showConditions && r.conditions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        label: Text(
                          '${r.conditions.length} rule${r.conditions.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onSelected: (v) {
                      if (v == 'duplicate') widget.onDuplicate();
                      if (v == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplicate'),
                          dense: true,
                        ),
                      ),
                      if (widget.canDelete)
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
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showConditions) ...[
                    ConditionsEditor(
                      conditions: r.conditions,
                      isDefault: r.conditions.isEmpty,
                      onChanged: widget.onChanged,
                      onMutated: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _labelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            isDense: true,
                          ),
                          onChanged: (v) => _changed(() => r.label = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: _StatusCodeField(
                          value: r.statusCode,
                          onChanged: (v) => _changed(() => r.statusCode = v),
                        ),
                      ),
                      if (widget.showWeight) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            initialValue: r.weight.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) =>
                                _changed(() => r.weight = int.tryParse(v) ?? 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Body type selector.
                  Row(
                    children: [
                      const Text(
                        'Body',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _BodyTypeSelector(
                        value: r.bodyType,
                        onChanged: (t) => _changed(() => r.bodyType = t),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (r.bodyType != BodyType.none)
                    BodyEditor(response: r, onChanged: widget.onChanged),
                  const SizedBox(height: 16),
                  // Headers.
                  HeadersEditor(
                    headers: r.headers,
                    onChanged: widget.onChanged,
                    onMutated: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  // Per-response delay + fault.
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: r.delayMs?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Delay override (ms)',
                            hintText: 'blank = use endpoint default',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _changed(
                            () => r.delayMs = v.trim().isEmpty
                                ? null
                                : int.tryParse(v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FaultSelector(
                          value: r.fault,
                          onChanged: (f) => _changed(() => r.fault = f),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCodeField extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _StatusCodeField({required this.value, required this.onChanged});

  static const _common = [
    200,
    201,
    204,
    400,
    401,
    403,
    404,
    409,
    422,
    429,
    500,
    502,
    503,
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: _common.contains(value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Status', isDense: true),
      hint: Text('$value', style: const TextStyle(fontFamily: 'monospace')),
      items: [
        for (final c in _common)
          DropdownMenuItem(
            value: c,
            child: Text(
              '$c',
              style: TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.statusColor(c),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

class _BodyTypeSelector extends StatelessWidget {
  final BodyType value;
  final ValueChanged<BodyType> onChanged;
  const _BodyTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyType>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: BodyType.values
          .map(
            (t) => ButtonSegment(
              value: t,
              label: Text(t.label, style: const TextStyle(fontSize: 11.5)),
            ),
          )
          .toList(),
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _FaultSelector extends StatelessWidget {
  final FaultType value;
  final ValueChanged<FaultType> onChanged;
  const _FaultSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<FaultType>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Fault injection',
        isDense: true,
      ),
      items: FaultType.values
          .map(
            (f) => DropdownMenuItem(
              value: f,
              child: Text(f.label, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: (f) => f == null ? null : onChanged(f),
    );
  }
}

/// Utility used by the body editor to validate/format JSON.
class JsonTools {
  static String? tryFormat(String input) {
    try {
      final obj = jsonDecode(input);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return null;
    }
  }

  /// Returns an error message if the JSON is invalid (ignoring template tokens).
  static String? validate(String input) {
    // Replace template tokens with `0`: valid as a bare JSON value and as
    // plain text when the token sits inside an already-quoted string.
    final stripped = input.replaceAll(TemplateEngine.tokenPattern, '0');
    try {
      jsonDecode(stripped);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
