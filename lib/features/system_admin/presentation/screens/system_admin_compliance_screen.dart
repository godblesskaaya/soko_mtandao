import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';

class SystemAdminComplianceScreen extends StatefulWidget {
  const SystemAdminComplianceScreen({super.key});

  @override
  State<SystemAdminComplianceScreen> createState() =>
      _SystemAdminComplianceScreenState();
}

class _SystemAdminComplianceScreenState
    extends State<SystemAdminComplianceScreen> {
  final _service = SystemAdminService();
  final _retentionController = TextEditingController();
  late Future<SystemAdminSnapshot> _future = _service.fetchSnapshot();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _retentionController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchSnapshot();
    });
  }

  Future<void> _setRetention() async {
    if (_isSubmitting) return;

    final days = int.tryParse(_retentionController.text.trim());
    if (days == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retention days must be a number.')),
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _service.setRetentionDays(days);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retention policy updated.')),
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
      title: 'Compliance & Risk',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      child: AdminLoadView<SystemAdminSnapshot>(
        future: _future,
        onRetry: _refresh,
        builder: (context, snapshot) {
          if (_retentionController.text.isEmpty) {
            _retentionController.text = snapshot.retentionDays.toString();
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audit retention',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _retentionController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Retention days',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _setRetention,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Update Retention'),
                        ),
                      ],
                    ),
                  ),
                ),
                const AdminSectionTitle(title: 'Refund SLA tracker'),
                if (snapshot.refundSla.isEmpty)
                  const Text('No refund SLA records.')
                else
                  ...snapshot.refundSla.map(
                    (row) {
                      final breached = row['is_breached'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          breached
                              ? Icons.timer_off_outlined
                              : Icons.timer_outlined,
                        ),
                        title: Text('Refund ${_text(row['id'])}'),
                        subtitle: Text(
                          'Booking: ${_text(row['booking_id'])}\nDue: ${_text(row['sla_due_at'])}',
                        ),
                        isThreeLine: true,
                        trailing: AdminStatusChip(
                          label: breached ? 'breached' : _text(row['status']),
                        ),
                      );
                    },
                  ),
                const AdminSectionTitle(title: 'Investigation queue'),
                if (snapshot.investigations.isEmpty)
                  const Text('No flagged audit events.')
                else
                  ...snapshot.investigations.map(
                    (row) => Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.manage_search_outlined),
                        title: Text(
                          '${_text(row['event_type'])} - ${_text(row['entity_type'])}',
                        ),
                        subtitle: Text(
                          'Entity: ${_text(row['entity_id'])}\nCreated: ${_text(row['created_at'])}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
