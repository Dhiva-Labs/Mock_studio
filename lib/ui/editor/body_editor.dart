import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/mock_response.dart';
import '../../services/template_engine.dart';
import 'response_card.dart';
import '../../theme/app_theme.dart';
import '../widgets/help_tip.dart';
import '../widgets/responsive.dart';

/// The response body editor: a monospace field with template-variable
/// insertion, JSON formatting/validation, and a preview of a rendered sample.
class BodyEditor extends StatefulWidget {
  final MockResponse response;
  final VoidCallback onChanged;
  const BodyEditor({
    super.key,
    required this.response,
    required this.onChanged,
  });

  @override
  State<BodyEditor> createState() => _BodyEditorState();
}

class _BodyEditorState extends State<BodyEditor> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  String? _jsonError;

  MockResponse get r => widget.response;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: r.body);
    _validate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _validate() {
    if (r.bodyType == BodyType.json && r.body.trim().isNotEmpty) {
      _jsonError = JsonTools.validate(r.body);
    } else {
      _jsonError = null;
    }
  }

  void _onChanged(String v) {
    r.body = v;
    _validate();
    setState(() {});
    widget.onChanged();
  }

  void _insertToken(String token) {
    final sel = _ctrl.selection;
    final text = _ctrl.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.replaceRange(start, end, token);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _onChanged(newText);
    _focus.requestFocus();
  }

  void _format() {
    final formatted = JsonTools.tryFormat(r.body);
    if (formatted != null) {
      _ctrl.text = formatted;
      _onChanged(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isJson = r.bodyType == BodyType.json;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar: wraps onto two lines on narrow screens.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<String>(
              // The HelpHover on the pill below replaces the plain tooltip.
              tooltip: '',
              onSelected: _insertToken,
              itemBuilder: (_) => TemplateEngine.palette
                  .map(
                    (p) => PopupMenuItem(
                      value: p.token,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.token,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            p.desc,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: HelpHover(
                'Adds a placeholder at the cursor. Each time the response '
                'is sent it is replaced with request data or a random '
                'value.',
                title: 'Insert variable',
                example: '{{params.id}} → 42 for /users/42',
                child: _pill(context, Icons.data_object, 'Insert variable'),
              ),
            ),
            if (isJson)
              HelpHover(
                'Re-indents the JSON so it is easier to read. Works only when '
                'the JSON is valid.',
                title: 'Format JSON',
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: _jsonError == null ? _format : null,
                  child: _pill(context, Icons.auto_fix_high, 'Format JSON'),
                ),
              ),
            if (isJson)
              HelpHover(
                'The body is checked as you type. {{...}} placeholders count '
                'as values, so they are not errors.',
                title: 'JSON check',
                example: '{"id": {{params.id}}}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _jsonError == null
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 14,
                        color: _jsonError == null
                            ? AppTheme.success
                            : scheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _jsonError == null ? 'Valid JSON' : 'Invalid JSON',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _jsonError == null
                              ? AppTheme.success
                              : scheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Editor.
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _jsonError != null
                  ? scheme.error.withValues(alpha: 0.5)
                  : scheme.outlineVariant,
            ),
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            maxLines: null,
            minLines: 6,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.all(12),
              hintText: '{\n  "key": "value"\n}',
            ),
            onChanged: _onChanged,
          ),
        ),
        if (_jsonError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'JSON: $_jsonError',
              style: TextStyle(fontSize: 11.5, color: scheme.error),
            ),
          ),
        const SizedBox(height: 8),
        _PreviewRow(response: r),
      ],
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    // 44 px tall on phones so it is easy to tap.
    final vertical = isPhone(context) ? 13.0 : 6.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: vertical),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a rendered sample of the body with template tokens filled in.
class _PreviewRow extends StatefulWidget {
  final MockResponse response;
  const _PreviewRow({required this.response});

  @override
  State<_PreviewRow> createState() => _PreviewRowState();
}

class _PreviewRowState extends State<_PreviewRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTokens = TemplateEngine.tokenPattern.hasMatch(
      widget.response.body,
    );
    if (!hasTokens) return const SizedBox.shrink();

    final preview = TemplateEngine.render(
      widget.response.body,
      TemplateContext(
        pathParams: {'id': '42', 'wildcard0': 'sample'},
        query: {'page': '1', 'limit': '20'},
        headers: {'Authorization': 'Bearer sample-token'},
        rawBody: '{"name":"Sample","email":"sample@example.com"}',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _open = !_open),
          child: Container(
            // A 48 px touch target on phones.
            constraints: BoxConstraints(minHeight: isPhone(context) ? 48 : 0),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 15,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                HelpHover(
                  'Shows the body with placeholders filled in from a sample '
                  'request. Real requests use their own values.',
                  title: 'Preview',
                  example: 'params.id = 42, query.page = 1',
                  child: Text(
                    _open ? 'Hide preview' : 'Preview with sample data',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: SelectableText(
              preview,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
      ],
    );
  }
}
