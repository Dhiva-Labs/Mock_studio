import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/mock_response.dart';

/// Editor for a response's rule conditions (used in the "conditional rules"
/// strategy). All conditions must match for the response to be chosen.
class ConditionsEditor extends StatefulWidget {
  final List<RuleCondition> conditions;
  final bool isDefault;
  final VoidCallback onChanged;
  final VoidCallback onMutated;
  const ConditionsEditor({
    super.key,
    required this.conditions,
    required this.isDefault,
    required this.onChanged,
    required this.onMutated,
  });

  @override
  State<ConditionsEditor> createState() => _ConditionsEditorState();
}

class _ConditionsEditorState extends State<ConditionsEditor> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, size: 16, color: scheme.tertiary),
              const SizedBox(width: 8),
              Text(
                widget.conditions.isEmpty
                    ? 'Default response (fallback)'
                    : 'Use this response when…',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() => widget.conditions.add(RuleCondition()));
                  widget.onChanged();
                  widget.onMutated();
                },
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add condition'),
              ),
            ],
          ),
          if (widget.conditions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No conditions — this response is returned when no other rule matches. '
                'Add a condition to make it selective.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ...widget.conditions.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ConditionRow(
                condition: c,
                showAnd: i > 0,
                onChanged: () {
                  widget.onChanged();
                  setState(() {});
                },
                onDelete: () {
                  setState(() => widget.conditions.removeAt(i));
                  widget.onChanged();
                  widget.onMutated();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final RuleCondition condition;
  final bool showAnd;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _ConditionRow({
    required this.condition,
    required this.showAnd,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsKey = condition.source != ConditionSource.method;
    final needsValue = condition.operator != ConditionOperator.exists;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showAnd)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              'AND',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: scheme.tertiary,
              ),
            ),
          ),
        // Source.
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<ConditionSource>(
            initialValue: condition.source,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            items: ConditionSource.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.label, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            onChanged: (s) {
              if (s != null) {
                condition.source = s;
                onChanged();
              }
            },
          ),
        ),
        if (needsKey) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 110,
            child: TextFormField(
              initialValue: condition.key,
              decoration: const InputDecoration(hintText: 'key', isDense: true),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              onChanged: (v) {
                condition.key = v;
                onChanged();
              },
            ),
          ),
        ],
        const SizedBox(width: 6),
        SizedBox(
          width: 118,
          child: DropdownButtonFormField<ConditionOperator>(
            initialValue: condition.operator,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            items: ConditionOperator.values
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.label, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            onChanged: (o) {
              if (o != null) {
                condition.operator = o;
                onChanged();
              }
            },
          ),
        ),
        if (needsValue) ...[
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              initialValue: condition.value,
              decoration: const InputDecoration(
                hintText: 'value',
                isDense: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              onChanged: (v) {
                condition.value = v;
                onChanged();
              },
            ),
          ),
        ] else
          const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 16),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
