import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/mock_response.dart';
import '../../services/template_engine.dart';
import 'response_card.dart';

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
        // Toolbar.
        Row(
          children: [
            _ToolbarButton(
              icon: Icons.add,
              label: 'Insert variable',
              onTap: null,
              menu: PopupMenuButton<String>(
                tooltip: 'Insert a dynamic variable',
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
                child: _pill(context, Icons.data_object, 'Insert variable'),
              ),
            ),
            const SizedBox(width: 8),
            if (isJson)
              InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: _jsonError == null ? _format : null,
                child: _pill(context, Icons.auto_fix_high, 'Format JSON'),
              ),
            const Spacer(),
            if (isJson)
              Row(
                children: [
                  Icon(
                    _jsonError == null
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 14,
                    color: _jsonError == null
                        ? const Color(0xFF16A34A)
                        : scheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _jsonError == null ? 'Valid JSON' : 'Invalid JSON',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _jsonError == null
                          ? const Color(0xFF16A34A)
                          : scheme.error,
                    ),
                  ),
                ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? menu;
  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.menu,
  });

  @override
  Widget build(BuildContext context) {
    if (menu != null) return menu!;
    return InkWell(onTap: onTap, child: const SizedBox());
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _open
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 15,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _open ? 'Hide preview' : 'Preview with sample data',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
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
