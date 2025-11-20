import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic async multi-select field (ID-based)
class AsyncMultiSelectField<T, ID> extends ConsumerWidget {
  /// Provider returning AsyncValue<List<T>> (can be .family)
  final ProviderListenable<AsyncValue<List<T>>> Function(WidgetRef) providerBuilder;

  /// Function to extract display text
  final String Function(T) getLabel;

  /// Function to extract ID (used for selection)
  final ID Function(T) getId;

  /// Label to show
  final String label;

  /// Currently selected IDs
  final List<ID> values;

  /// Called when user updates the selected list
  final void Function(List<ID>)? onChanged;

  /// Optional validator
  final FormFieldValidator<List<ID>>? validator;

  /// Called the first time the field is tapped (for lazy loading)
  final Future<void> Function(WidgetRef)? onFetch;

  const AsyncMultiSelectField({
    super.key,
    required this.providerBuilder,
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
  final asyncValue = ref.watch(providerBuilder(ref));

  return asyncValue.when(
    data: (items) {
      print("items loaded: $items");
      final selectedLabels = items
          .where((item) => values.contains(getId(item)))
          .map(getLabel)
          .join(', ');

      return FormField<List<ID>>(
        initialValue: values,
        validator: validator,
        builder: (state) {
          return InkWell(
            onTap: () async {
              if (onFetch != null) {
                await onFetch!(ref);
              }

              final selected = await showDialog<List<ID>>(
                context: context,
                builder: (context) => _MultiSelectDialog<T, ID>(
                  items: items,
                  getLabel: getLabel,
                  getId: getId,
                  initial: values,
                  label: label,
                ),
              );

              if (selected != null) {
                state.didChange(selected);
                if (onChanged != null) {
                  onChanged!(selected);
                }
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                errorText: state.errorText,
              ),
              child: Text(
                selectedLabels.isEmpty ? 'Select $label' : selectedLabels,
              ),
            ),
          );
        },
      );
    },
    loading: () => TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      controller: TextEditingController(text: "Loading..."),
    ),
    error: (err, _) => TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: "Error loading $label",
      ),
    ),
  );
}
}

/// Internal dialog for selecting multiple items
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
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          children: [
            for (final item in widget.items)
              CheckboxListTile(
                title: Text(widget.getLabel(item)),
                value: selected.contains(widget.getId(item)),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selected.add(widget.getId(item));
                    } else {
                      selected.remove(widget.getId(item));
                    }
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selected),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
