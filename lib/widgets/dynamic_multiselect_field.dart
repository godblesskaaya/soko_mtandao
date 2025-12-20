import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncMultiSelectField<T, ID> extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<T>>> provider;
  final String Function(T) getLabel;
  final ID Function(T) getId;
  final String label;
  final List<ID> values;
  final void Function(List<ID>)? onChanged;
  final FormFieldValidator<List<ID>>? validator;
  
  /// Called before opening the dialog. 
  /// Return true to proceed opening, false to cancel.
  final Future<void> Function(WidgetRef)? onFetch;

  const AsyncMultiSelectField({
    super.key,
    required this.provider,
    required this.getLabel,
    required this.getId,
    required this.label,
    this.values = const [],
    this.onChanged,
    this.validator,
    this.onFetch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider
    final asyncValue = ref.watch(provider);

    return FormField<List<ID>>(
      initialValue: values,
      validator: validator,
      // Key helps reset state if parent changes 'values' drastically
      key: ValueKey(values.hashCode), 
      builder: (state) {
        // 1. Determine Display Text and Icons based on Async State
        String displayText = 'Select $label';
        Widget? suffixIcon;
        bool isDisabled = false;

        asyncValue.when(
          data: (items) {
            final selectedLabels = items
                .where((item) => state.value?.contains(getId(item)) ?? false)
                .map(getLabel)
                .join(', ');
            
            if (selectedLabels.isNotEmpty) {
              displayText = selectedLabels;
            }
            suffixIcon = const Icon(Icons.arrow_drop_down);
          },
          loading: () {
            displayText = 'Loading $label...';
            suffixIcon = const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 12, 
                height: 12, 
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
            // If strictly loading and not refreshing, you might want to disable tap:
            // isDisabled = true; 
          },
          error: (err, stack) {
            displayText = 'Error loading options';
            suffixIcon = const Icon(Icons.error, color: Colors.red);
          },
        );

        // 2. The Input Decorator
        return InkWell(
          onTap: isDisabled
              ? null
              : () async {
                  // A. Handle Lazy Loading
                  if (onFetch != null) {
                    await onFetch!(ref);
                  }

                  // B. Ensure data is ready before showing dialog
                  // We read the provider status *after* the potential fetch
                  final currentAsync = ref.read(provider);

                  if (context.mounted) {
                    currentAsync.whenOrNull(
                      data: (items) async {
                        // C. Show Dialog
                        final selectedIds = await showDialog<List<ID>>(
                          context: context,
                          builder: (context) => _MultiSelectDialog<T, ID>(
                            items: items,
                            getLabel: getLabel,
                            getId: getId,
                            initial: state.value ?? [],
                            label: label,
                          ),
                        );

                        // D. Handle Selection
                        if (selectedIds != null) {
                          state.didChange(selectedIds);
                          if (onChanged != null) {
                            onChanged!(selectedIds);
                          }
                        }
                      },
                      error: (error, _) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to load items: $error')),
                        );
                      },
                      // If still loading after onFetch, arguably we shouldn't open dialog 
                      // or we should show a loading dialog. 
                    );
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              errorText: state.errorText,
              suffixIcon: suffixIcon,
            ),
            isEmpty: false,
            child: Text(
              displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: asyncValue.hasError 
                  ? TextStyle(color: Theme.of(context).colorScheme.error) 
                  : null,
            ),
          ),
        );
      },
    );
  }
}

// --- Improved Dialog ---

class _MultiSelectDialog<T, ID> extends StatefulWidget {
  final List<T> items;
  final String Function(T) getLabel;
  final ID Function(T) getId;
  final List<ID> initial;
  final String label;

  const _MultiSelectDialog({
    required this.items,
    required this.getLabel,
    required this.getId,
    required this.initial,
    required this.label,
  });

  @override
  State<_MultiSelectDialog<T, ID>> createState() => _MultiSelectDialogState<T, ID>();
}

class _MultiSelectDialogState<T, ID> extends State<_MultiSelectDialog<T, ID>> {
  late List<ID> selected;

  @override
  void initState() {
    super.initState();
    selected = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select ${widget.label}'),
      // Use constrained width for better tablet/web look
      content: SizedBox(
        width: 400, 
        height: MediaQuery.of(context).size.height * 0.6,
        // Use ListView.builder for performance with large lists
        child: widget.items.isEmpty 
          ? const Center(child: Text("No items available"))
          : ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final id = widget.getId(item);
                final isSelected = selected.contains(id);
                
                return CheckboxListTile(
                  title: Text(widget.getLabel(item)),
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    });
                  },
                );
              },
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}