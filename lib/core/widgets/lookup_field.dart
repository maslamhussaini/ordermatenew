import 'package:flutter/material.dart';
import 'package:ordermate/core/widgets/generic_selection_screen.dart';

class LookupField<TItem, TValue> extends StatefulWidget {
  const LookupField({
    required this.label,
    required this.items,
    required this.labelBuilder,
    required this.valueBuilder,
    required this.onChanged,
    super.key,
    this.value,
    this.onAdd,
    this.validationError,
    this.enabled = true,
    this.hint,
    this.validator,
    this.prefixIcon,
  });

  final String label;
  final TValue? value;
  final List<TItem> items;
  final String Function(TItem) labelBuilder;
  final TValue Function(TItem) valueBuilder;
  final ValueChanged<TValue?> onChanged;
  final Future<void> Function(String)? onAdd;
  final FormFieldValidator<TValue>? validator;
  final String? validationError;
  final bool enabled;
  final String? hint;
  final IconData? prefixIcon;

  @override
  State<LookupField<TItem, TValue>> createState() =>
      _LookupFieldState<TItem, TValue>();
}

class _LookupFieldState<TItem, TValue>
    extends State<LookupField<TItem, TValue>> {
  final _fieldKey = GlobalKey<FormFieldState<TValue>>();

  @override
  void didUpdateWidget(LookupField<TItem, TValue> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      // Sync the internal FormField value with the external prop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fieldKey.currentState?.didChange(widget.value);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<TValue>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (FormFieldState<TValue> field) {
        // Find the current selected item object to display its label
        // Use field.value to ensure we show the most current state
        TItem? selectedItem;
        try {
          if (field.value != null) {
            selectedItem = widget.items
                .firstWhere((item) => widget.valueBuilder(item) == field.value);
          }
        } catch (_) {
          // If value not found in items (e.g. inactive or newly added but not yet in list)
        }

        final displayLabel = selectedItem != null
            ? widget.labelBuilder(selectedItem)
            : (widget.hint ?? 'Select ${widget.label}');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.enabled
                    ? () async {
                        final result = await Navigator.push<TItem>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GenericSelectionScreen<TItem>(
                              title: 'Select ${widget.label}',
                              items: widget.items,
                              labelBuilder: widget.labelBuilder,
                            ),
                          ),
                        );

                        if (result != null) {
                          final newValue = widget.valueBuilder(result);
                          field.didChange(newValue);
                          widget.onChanged(newValue);
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    labelText: widget.label,
                    prefixIcon: widget.prefixIcon != null
                        ? Icon(widget.prefixIcon)
                        : null,
                    errorText: field.errorText ?? widget.validationError,
                    suffixIcon: widget.enabled
                        ? const Icon(Icons.arrow_drop_down)
                        : null,
                    fillColor: widget.enabled ? null : Colors.grey.shade100,
                    filled: !widget.enabled,
                  ),
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedItem != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (widget.onAdd != null && widget.enabled) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton.filledTonal(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add new ${widget.label}',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(14),
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
        title: Text('Add New ${widget.label}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.label} name',
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
                  await widget.onAdd!(controller.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text('${widget.label} Added Successfully!')),
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
