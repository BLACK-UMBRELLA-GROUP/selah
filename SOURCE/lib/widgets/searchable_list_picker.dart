// Simple searchable single/multi picker over a static list — stands in
// for a real country/language/ethnicity search backend (mock_reference_
// lists.dart). Opens as a bottom sheet; good enough for today's testable
// build, per the same scope note used elsewhere in this app.

import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_state_widgets.dart';

Future<String?> showSingleSearchPicker(
  BuildContext context,
  List<String> items, {
  String? current,
  String searchHint = 'Search…',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: SelahColors.modalSheetSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _PickerSheet(
      items: items,
      multi: false,
      initialSelection: current == null ? const [] : [current],
      searchHint: searchHint,
    ),
  );
}

Future<List<String>?> showMultiSearchPicker(
  BuildContext context,
  List<String> items, {
  List<String> current = const [],
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    backgroundColor: SelahColors.modalSheetSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _PickerSheet(items: items, multi: true, initialSelection: current),
  );
}

class _PickerSheet extends StatefulWidget {
  final List<String> items;
  final bool multi;
  final List<String> initialSelection;
  final String searchHint;

  const _PickerSheet({
    required this.items,
    required this.multi,
    required this.initialSelection,
    this.searchHint = 'Search…',
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final TextEditingController _search = TextEditingController();
  late final List<String> _selected = List<String>.from(
    widget.initialSelection,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) => i.toLowerCase().contains(_search.text.toLowerCase()))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: SelahText.body(size: 15, color: SelahColors.inkColor),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: SelahText.body(
                      size: 15,
                      color: SelahColors.ink(0.38),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: SelahColors.ink(0.38),
                      size: 18,
                    ),
                    filled: true,
                    fillColor: SelahColors.iconButtonBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? SelahEmptyState(
                        icon: Icons.search_off,
                        message:
                            "No matches for that — try a different spelling.",
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final selected = _selected.contains(item);
                          return ListTile(
                            title: Text(
                              item,
                              style: SelahText.body(
                                size: 14,
                                color: SelahColors.inkColor,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: SelahColors.ink(0.70),
                                    size: 18,
                                  )
                                : null,
                            onTap: () {
                              if (widget.multi) {
                                setState(
                                  () => selected
                                      ? _selected.remove(item)
                                      : _selected.add(item),
                                );
                              } else {
                                Navigator.of(context).pop(item);
                              }
                            },
                          );
                        },
                      ),
              ),
              if (widget.multi)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: Text('Done (${_selected.length})'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
