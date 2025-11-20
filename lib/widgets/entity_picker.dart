import 'package:flutter/material.dart';

Future<T?> showEntityPicker<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function() fetchItems,
  required String Function(T) display,
}) async {
  final items = await fetchItems();
  if (items.isEmpty) return null;
  return showModalBottomSheet<T>(
    context: context,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 420),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (iCtx, i) {
                final e = items[i];
                return ListTile(
                  title: Text(display(e)),
                  onTap: () => Navigator.of(ctx).pop(e),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}