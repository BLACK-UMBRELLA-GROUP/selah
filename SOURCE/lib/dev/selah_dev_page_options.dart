import 'dart:async';

import 'package:flutter/material.dart';

import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_dev_tool_section.dart';

/// A choice delegates to an existing page/scenario owner. It never owns data,
/// grants access, or executes while the menu is being built.
@immutable
class SelahDevPageOption {
  final String id;
  final String label;
  final String group;
  final FutureOr<void> Function()? onSelected;
  final bool selected;
  final String? unavailableReason;

  const SelahDevPageOption({
    required this.id,
    required this.label,
    required this.group,
    this.onSelected,
    this.selected = false,
    this.unavailableReason,
  });
}

/// Independent category dropdowns for the third developer door. A context
/// change invalidates an already-open menu before any callback can run.
class SelahDevPageOptions extends StatefulWidget {
  final List<SelahDevPageOption> options;
  final String contextKey;
  final bool busy;

  const SelahDevPageOptions({
    super.key,
    required this.options,
    required this.contextKey,
    this.busy = false,
  });

  @override
  State<SelahDevPageOptions> createState() => _SelahDevPageOptionsState();
}

class _SelahDevPageOptionsState extends State<SelahDevPageOptions> {
  final Map<String, String> _lastSelections = {};
  String? _menuContext;
  int? _menuGeneration;
  String? _failure;
  String? _failureGroup;
  String? _workingGroup;
  bool _working = false;
  String? _openGroup;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    SelahDeveloperAccess.authorizationChanges.addListener(_authorityChanged);
  }

  @override
  void dispose() {
    SelahDeveloperAccess.authorizationChanges.removeListener(_authorityChanged);
    super.dispose();
  }

  void _authorityChanged() {
    if (!mounted) return;
    setState(() {
      _generation++;
      _lastSelections.clear();
      _failure = null;
      _working = false;
      _openGroup = null;
      _failureGroup = null;
      _workingGroup = null;
    });
  }

  @override
  void didUpdateWidget(covariant SelahDevPageOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final catalogChanged =
        oldWidget.options.length != widget.options.length ||
        oldWidget.options.asMap().entries.any(
          (entry) =>
              entry.value.id != widget.options[entry.key].id ||
              entry.value.group != widget.options[entry.key].group,
        );
    if (oldWidget.contextKey != widget.contextKey || catalogChanged) {
      _generation++;
      _lastSelections.clear();
      _failure = null;
      _working = false;
      _openGroup = null;
      _failureGroup = null;
      _workingGroup = null;
      // Retain the old menu context so its eventual selection is refused.
    }
  }

  Future<void> _select(String group, String? id) async {
    if (id == null ||
        _working ||
        widget.busy ||
        _openGroup != group ||
        _menuContext != widget.contextKey ||
        _menuGeneration != _generation ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    SelahDevPageOption? option;
    for (final candidate in widget.options) {
      if (candidate.id == id && candidate.group == group) option = candidate;
    }
    final callback = option?.onSelected;
    if (callback == null) return;
    final generation = _generation;
    setState(() {
      _working = true;
      _failure = null;
      _failureGroup = null;
      _workingGroup = group;
      _openGroup = null;
    });
    try {
      await callback();
      if (!mounted || generation != _generation) return;
      setState(() => _lastSelections[group] = id);
    } catch (error, stack) {
      debugPrint('SELAH page option failed (${error.runtimeType}).\n$stack');
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = 'This option could not be applied. Try again.';
        _failureGroup = group;
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _working = false;
          _workingGroup = null;
        });
      }
    }
  }

  String? _valueFor(String group) {
    final options = widget.options.where((option) => option.group == group);
    final hasCurrentSelection = options.any((option) => option.selected);
    for (final option in options) {
      if (option.id == _lastSelections[group] &&
          option.onSelected != null &&
          (option.selected || !hasCurrentSelection)) {
        return option.id;
      }
    }
    for (final option in options) {
      if (option.selected && option.onSelected != null) return option.id;
    }
    return null;
  }

  SelahDevPageOption? _optionById(String? id) {
    for (final option in widget.options) {
      if (option.id == id) return option;
    }
    return null;
  }

  void _toggleMenu(String group) {
    if (_working || widget.busy || !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    setState(() {
      _openGroup = _openGroup == group ? null : group;
      if (_openGroup != null) {
        _menuContext = widget.contextKey;
        _menuGeneration = _generation;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) {
        return const SizedBox.shrink();
      }
      assert(
        widget.options.map((option) => option.id).toSet().length ==
            widget.options.length,
        'Page-option IDs must be unique per context.',
      );
      final enabled = !widget.busy && !_working && widget.options.isNotEmpty;
      final groups = <String, List<SelahDevPageOption>>{};
      for (final option in widget.options) {
        groups.putIfAbsent(option.group, () => []).add(option);
      }
      return Column(
        key: const ValueKey('dev_page_options_control'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Page options',
            style: SelahText.body(size: 13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            Text('No page-specific options', style: SelahText.subtext(size: 12)),
          for (final entry in groups.entries) ...[
            SelahDevToolSection(
              key: ValueKey('dev_page_options_group_${entry.key}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(entry.key, style: SelahText.body(size: 12)),
                  const SizedBox(height: 8),
                  _trigger(
                    entry.key,
                    enabled,
                    _optionById(_valueFor(entry.key)),
                  ),
                  if (_openGroup == entry.key) ...[
                    const SizedBox(height: 10),
                    _inlineMenu(context, entry.value),
                  ],
                  if (_failure != null && _failureGroup == entry.key) ...[
                    const SizedBox(height: 10),
                    Text(
                      _failure!,
                      key: const ValueKey('dev_page_option_error'),
                      style: SelahText.subtext(size: 12, color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    },
  );

  Widget _trigger(String group, bool enabled, SelahDevPageOption? selected) =>
      Semantics(
        button: true,
        expanded: _openGroup == group,
        label: group,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('dev_page_options_dropdown_$group'),
            onTap: enabled ? () => _toggleMenu(group) : null,
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SelahColors.surfaceEmphasisFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SelahColors.surfaceEmphasisBorder),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          (_working && _workingGroup == group) || widget.busy
                              ? 'Applying…'
                              : selected?.label ??
                                    (widget.options.isEmpty
                                        ? 'No page-specific options'
                                        : 'Choose a page option'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SelahText.body(
                            size: 13,
                            color: enabled ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _openGroup == group
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: enabled ? Colors.white70 : Colors.white38,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _inlineMenu(BuildContext context, List<SelahDevPageOption> options) {
    final children = <Widget>[];
    for (final option in options) {
      children.add(_optionRow(option));
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .52,
      ),
      child: DecoratedBox(
        key: const ValueKey('dev_page_options_inline_menu'),
        decoration: BoxDecoration(
          color: SelahColors.modalSheetSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            key: const ValueKey('dev_page_options_scroll'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(SelahDevPageOption option) => Semantics(
    button: option.onSelected != null,
    enabled: option.onSelected != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(option.id),
        onTap: option.onSelected == null
            ? null
            : () => unawaited(_select(option.group, option.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: SelahText.body(
                    size: 13,
                    color: option.onSelected == null
                        ? Colors.white54
                        : Colors.white,
                  ),
                ),
                if (option.onSelected == null &&
                    option.unavailableReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      option.unavailableReason!,
                      style: SelahText.subtext(size: 11, color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
