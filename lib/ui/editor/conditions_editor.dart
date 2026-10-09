import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/mock_response.dart';
import '../widgets/help_tip.dart';

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
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LabelWithHelp(
                    widget.conditions.isEmpty
                        ? 'Default response (fallback)'
                        : 'Use this response when…',
                    widget.conditions.isEmpty
                        ? 'With no conditions, this response is the fallback: it '
                              "is sent when no other response's conditions all "
                              'match. Add a condition to make it selective.'
                        : 'Sent only when every condition below matches. '
                              'Responses are checked from top to bottom and the '
                              'first full match wins.',
                    example: widget.conditions.isEmpty
                        ? null
                        : 'Query param "page" equals "2"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
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
                // Follows its condition when one above it is removed.
                key: ObjectKey(c),
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
    super.key,
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

    final andLabel = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: HelpHover(
        'Every condition must match, not only one of them.',
        title: 'AND',
        child: Text(
          'AND',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: scheme.tertiary,
          ),
        ),
      ),
    );
    final source = SizedBox(
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
                child: _hover(
                  _sourceHelp(s),
                  child: Text(s.label, style: const TextStyle(fontSize: 12)),
                ),
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
    );
    final key = SizedBox(
      width: 110,
      child: _hover(
        _keyHelp(condition.source),
        child: TextFormField(
          initialValue: condition.key,
          decoration: InputDecoration(
            hintText: _keyHint(condition.source),
            isDense: true,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          onChanged: (v) {
            condition.key = v;
            onChanged();
          },
        ),
      ),
    );
    final operator = SizedBox(
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
                child: _hover(
                  _operatorHelp(o),
                  child: Text(o.label, style: const TextStyle(fontSize: 12)),
                ),
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
    );
    final value = Expanded(
      child: _hover(
        _valueHelp(condition),
        child: TextFormField(
          initialValue: condition.value,
          decoration: InputDecoration(
            hintText: _valueHint(condition),
            isDense: true,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          onChanged: (v) {
            condition.value = v;
            onChanged();
          },
        ),
      ),
    );
    final delete = IconButton(
      tooltip: 'Remove condition',
      icon: const Icon(Icons.close, size: 16),
      onPressed: onDelete,
    );

    // One row when there's room (about 540 px); otherwise source and key on
    // the first line, operator and value on the second.
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 540) {
          return Row(
            children: [
              if (showAnd) andLabel,
              source,
              if (needsKey) ...[const SizedBox(width: 6), key],
              const SizedBox(width: 6),
              operator,
              if (needsValue) ...[
                const SizedBox(width: 6),
                value,
              ] else
                const Spacer(),
              delete,
            ],
          );
        }
        Widget fill(Widget w) => w is SizedBox ? Expanded(child: w.child!) : w;
        return Column(
          children: [
            Row(
              children: [
                if (showAnd) andLabel,
                fill(source),
                if (needsKey) ...[const SizedBox(width: 6), fill(key)],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                fill(operator),
                if (needsValue) ...[
                  const SizedBox(width: 6),
                  value,
                ] else
                  const Spacer(),
                delete,
              ],
            ),
          ],
        );
      },
    );
  }
}

typedef _Help = ({String title, String message, String? example});

/// A [HelpHover] built from a title / message / example record.
Widget _hover(_Help h, {required Widget child}) =>
    HelpHover(h.message, title: h.title, example: h.example, child: child);

/// Hover help for each place a condition can read from.
_Help _sourceHelp(ConditionSource s) => switch (s) {
  ConditionSource.query => (
    title: 'Query param',
    message: 'Checks a query string parameter, the part of the URL after ?.',
    example: '/users?page=2 → key page, value 2',
  ),
  ConditionSource.header => (
    title: 'Header',
    message: 'Checks a request header. Header names are not case-sensitive.',
    example: 'X-API-Key: abc123',
  ),
  ConditionSource.pathParam => (
    title: 'Path param',
    message: 'Checks a :param captured from the endpoint path.',
    example: '/users/:id → key id',
  ),
  ConditionSource.bodyJson => (
    title: 'Body field (JSON path)',
    message:
        'Checks a field in the JSON request body. Use dots for nested '
        'fields.',
    example: 'user.role in {"user": {"role": "admin"}}',
  ),
  ConditionSource.method => (
    title: 'HTTP method',
    message:
        'Checks the request method. Useful when the endpoint method is ANY.',
    example: 'POST',
  ),
};

String _keyHint(ConditionSource s) => switch (s) {
  ConditionSource.query => 'param name',
  ConditionSource.header => 'header name',
  ConditionSource.pathParam => 'param name',
  ConditionSource.bodyJson => 'user.role',
  ConditionSource.method => 'key',
};

_Help _keyHelp(ConditionSource s) => switch (s) {
  ConditionSource.query => (
    title: 'Query parameter name',
    message: 'The name of the query parameter to read.',
    example: 'page  (for ?page=2)',
  ),
  ConditionSource.header => (
    title: 'Header name',
    message: 'The name of the request header to read. Case does not matter.',
    example: 'X-API-Key',
  ),
  ConditionSource.pathParam => (
    title: 'Path parameter name',
    message: 'The name of the path parameter, without the colon.',
    example: 'id  (for /users/:id)',
  ),
  ConditionSource.bodyJson => (
    title: 'JSON path',
    message: 'Dotted path to a field in the JSON request body.',
    example: 'user.role',
  ),
  ConditionSource.method => (
    title: 'Key',
    message: 'Not used when checking the HTTP method.',
    example: null,
  ),
};

/// Hover help for each comparison operator.
_Help _operatorHelp(ConditionOperator o) => switch (o) {
  ConditionOperator.equals => (
    title: 'equals',
    message: 'Matches when the value is exactly the same. Case-sensitive.',
    example: 'page equals 2',
  ),
  ConditionOperator.notEquals => (
    title: 'does not equal',
    message: 'Matches when the value is different, or missing.',
    example: 'status does not equal active',
  ),
  ConditionOperator.contains => (
    title: 'contains',
    message: 'Matches when your text appears anywhere in the value.',
    example: 'User-Agent contains Mobile',
  ),
  ConditionOperator.exists => (
    title: 'exists',
    message:
        'Matches when the value is present and not empty. No value needed.',
    example: 'Authorization exists',
  ),
  ConditionOperator.regex => (
    title: 'matches regex',
    message:
        'Matches a regular expression, a pattern for text. It can match '
        'anywhere in the value unless you anchor it with ^ and \$.',
    example: '^[0-9]+\$ → digits only',
  ),
  ConditionOperator.greaterThan => (
    title: 'greater than',
    message: 'Compares as numbers. Values that are not numbers never match.',
    example: 'quantity greater than 10',
  ),
  ConditionOperator.lessThan => (
    title: 'less than',
    message: 'Compares as numbers. Values that are not numbers never match.',
    example: 'age less than 18',
  ),
};

String _valueHint(RuleCondition c) {
  if (c.source == ConditionSource.method) return 'POST';
  return switch (c.operator) {
    ConditionOperator.regex => 'pattern',
    ConditionOperator.greaterThan || ConditionOperator.lessThan => 'number',
    _ => 'value',
  };
}

_Help _valueHelp(RuleCondition c) {
  if (c.source == ConditionSource.method &&
      c.operator != ConditionOperator.regex) {
    return (
      title: 'Method',
      message: 'The method to compare with, in capitals.',
      example: 'POST',
    );
  }
  return switch (c.operator) {
    ConditionOperator.regex => (
      title: 'Pattern',
      message: 'A regular expression to test the value against.',
      example: '^admin matches admin and administrator',
    ),
    ConditionOperator.greaterThan || ConditionOperator.lessThan => (
      title: 'Number',
      message: 'The number to compare with.',
      example: '100',
    ),
    _ => (
      title: 'Value',
      message: 'The text to compare with. Matching is case-sensitive.',
      example: '2',
    ),
  };
}
