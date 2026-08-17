import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';

class SystemAdminDisputeReviewScreen extends StatefulWidget {
  final String disputeId;

  const SystemAdminDisputeReviewScreen({
    super.key,
    required this.disputeId,
  });

  @override
  State<SystemAdminDisputeReviewScreen> createState() =>
      _SystemAdminDisputeReviewScreenState();
}

class _SystemAdminDisputeReviewScreenState
    extends State<SystemAdminDisputeReviewScreen> {
  final _service = SystemAdminService();
  final _notesController = TextEditingController();
  late Future<AdminRow?> _future = _service.fetchDispute(widget.disputeId);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchDispute(widget.disputeId);
    });
  }

  Future<void> _setStatus(String status) async {
    if (_isSubmitting) return;

    try {
      setState(() => _isSubmitting = true);
      await _service.setDisputeStatus(
        disputeId: widget.disputeId,
        status: status,
        notes: _notesController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispute marked $status.')),
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
      title: 'Dispute Review',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      child: AdminLoadView<AdminRow?>(
        future: _future,
        onRetry: _refresh,
        builder: (context, row) {
          if (row == null) {
            return const AdminEmptyState(message: 'Dispute not found.');
          }

          _notesController.text = _notesController.text.isEmpty
              ? _text(row['admin_notes'], fallback: '')
              : _notesController.text;

          return ListView(
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ticket ${_text(row['ticket_number'])}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          AdminStatusChip(
                            label: _text(row['status'], fallback: 'submitted'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AdminInfoRow(
                        label: 'Booking',
                        value: _text(row['booking_id']),
                      ),
                      AdminInfoRow(
                        label: 'Submitted by',
                        value: _text(row['submitted_by']),
                      ),
                      AdminInfoRow(
                        label: 'Category',
                        value: _text(row['category']),
                      ),
                      AdminInfoRow(
                        label: 'SLA due',
                        value: _text(row['sla_due_at']),
                      ),
                      AdminInfoRow(
                        label: 'Created',
                        value: _text(row['created_at']),
                      ),
                    ],
                  ),
                ),
              ),
              const AdminSectionTitle(title: 'Customer description'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_text(row['description'])),
                ),
              ),
              const AdminSectionTitle(title: 'Admin notes'),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Decision notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _setStatus('under_review'),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Mark Under Review'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _setStatus('resolved'),
                    icon: const Icon(Icons.check),
                    label: const Text('Resolve'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _setStatus('rejected'),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ],
              ),
            ],
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
