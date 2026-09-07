import 'package:flutter/material.dart';

/// A reusable generic searchable dropdown widget using [DropdownMenu].
/// Features:
/// - Search/Filter functionality (Like %query%)
/// - "Add New" button support
/// - customizable width and labels
class SearchableDropdown<TItem, TValue> extends StatelessWidget {
  const SearchableDropdown({
    required this.label,
    required this.items,
    required this.labelBuilder,
    required this.valueBuilder,
    required this.onChanged,
    super.key,
    this.value,
    this.onAdd,
    this.width,
    this.validationError,
  });
  final String label;
  final TValue? value;
  final List<TItem> items;
  final String Function(TItem) labelBuilder;
  final TValue Function(TItem) valueBuilder;
  final ValueChanged<TValue?> onChanged;
  final Future<void> Function(String)? onAdd;
  final double? width;
  final String? validationError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = width ?? constraints.maxWidth;
        // Subtract width for the Add button if it exists (50px approx)
        final menuWidth = onAdd != null ? effectiveWidth - 58 : effectiveWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownMenu<TValue>(
              width: menuWidth,
              label: Text(label),
              initialSelection: value,
              enableFilter: true,
              requestFocusOnTap: true,
              errorText: validationError,
              // Explicitly implement "Like %%" filtering (Contains)
              filterCallback: (entries, query) {
                if (query.isEmpty) return entries;
                return entries
                    .where(
                      (entry) => entry.label
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                    )
                    .toList();
              },
              dropdownMenuEntries: items.map((item) {
                return DropdownMenuEntry<TValue>(
                  value: valueBuilder(item),
                  label: labelBuilder(item),
                );
              }).toList(),
              onSelected: onChanged,
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4), // Align with input
                child: IconButton.filledTonal(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add new $label',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label name',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  // Ensure we close dialog FIRST to avoid context issues if onAdd succeeds
                  // But we wait for onAdd to catch errors.
                  await onAdd!(controller.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$label Added Successfully!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
