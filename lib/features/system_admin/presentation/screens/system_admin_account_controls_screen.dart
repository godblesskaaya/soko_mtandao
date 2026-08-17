import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';

class SystemAdminAccountControlsScreen extends StatefulWidget {
  const SystemAdminAccountControlsScreen({super.key});

  @override
  State<SystemAdminAccountControlsScreen> createState() =>
      _SystemAdminAccountControlsScreenState();
}

class _SystemAdminAccountControlsScreenState
    extends State<SystemAdminAccountControlsScreen> {
  final _service = SystemAdminService();
  final _userIdController = TextEditingController();
  final _reasonController = TextEditingController();
  late Future<List<AdminRow>> _future = _service.fetchActiveFreezes();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchActiveFreezes();
    });
  }

  Future<void> _setFreeze(bool isFrozen) async {
    if (_isSubmitting) return;

    final userId = _userIdController.text.trim();
    final reason = _reasonController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User id is required.')),
      );
      return;
    }
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required.')),
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _service.setAccountFreeze(
        userId: userId,
        isFrozen: isFrozen,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFrozen ? 'Account frozen.' : 'Account unfrozen.')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Account Controls',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Freeze or unfreeze account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(labelText: 'User id'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _isSubmitting ? null : () => _setFreeze(true),
                        icon: const Icon(Icons.lock),
                        label: const Text('Freeze'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isSubmitting ? null : () => _setFreeze(false),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Unfreeze'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const AdminSectionTitle(title: 'Currently frozen accounts'),
          AdminLoadView<List<AdminRow>>(
            future: _future,
            onRetry: _refresh,
            builder: (context, rows) {
              if (rows.isEmpty) {
                return const Text('No active account freezes.');
              }

              return Column(
                children: rows
                    .map(
                      (row) => Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.lock_person_outlined),
                          title: Text(_text(row['user_id'])),
                          subtitle: Text(
                            '${_text(row['reason'])}\nStarted: ${_text(row['started_at'])}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
