import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic async dropdown field (ID-based)
class AsyncDropdownField<T, ID> extends ConsumerWidget {
  /// Provider returning AsyncValue<List<T>> (can be .family)
  final ProviderListenable<AsyncValue<List<T>>> Function(WidgetRef) providerBuilder;

  /// Function to extract display text
  final String Function(T) getLabel;

  /// Function to extract ID (used as dropdown value)
  final ID Function(T) getId;

  /// Label to show
  final String label;

  /// Currently selected ID
  final ID? value;

  /// Called when user selects a new ID
  final void Function(ID?)? onChanged;

  /// Optional validator
  final String? Function(ID?)? validator;

  /// Called the first time dropdown is tapped (for lazy loading)
  final Future<void> Function(WidgetRef)? onFetch;

  const AsyncDropdownField({
    super.key,
    required this.providerBuilder,
    required this.getLabel,
    required this.getId,
    required this.label,
    this.value,
    this.onChanged,
    this.validator,
    this.onFetch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(providerBuilder(ref));

    final items = (asyncValue.valueOrNull ?? []);

    return DropdownButtonFormField<ID>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: items
          .map(
            (item) => DropdownMenuItem<ID>(
              value: getId(item),
              child: Text(getLabel(item)),
            ),
          )
          .toList(),
      onTap: () async {
        if (onFetch != null) {
          await onFetch!(ref);
        }
      },
      onChanged: onChanged,
      validator: validator ?? (v) => v == null ? "Please select $label" : null,
      hint: asyncValue.when(
        data: (list) {
          if (list.isEmpty) return Text("No ${label.toLowerCase()}s available");
          return Text("Select $label");
        },
        loading: () => Text("Loading ${label.toLowerCase()}s..."),
        error: (err, _) => Text("Error loading ${label.toLowerCase()}s"),
      ),
    );
  }
}
