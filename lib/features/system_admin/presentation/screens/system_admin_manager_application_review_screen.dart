import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';

class SystemAdminManagerApplicationReviewScreen extends StatefulWidget {
  final String applicationId;

  const SystemAdminManagerApplicationReviewScreen({
    super.key,
    required this.applicationId,
  });

  @override
  State<SystemAdminManagerApplicationReviewScreen> createState() =>
      _SystemAdminManagerApplicationReviewScreenState();
}

class _SystemAdminManagerApplicationReviewScreenState
    extends State<SystemAdminManagerApplicationReviewScreen> {
  final _service = SystemAdminService();
  final _notesController = TextEditingController();
  late Future<AdminRow?> _future =
      _service.fetchManagerApplication(widget.applicationId);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchManagerApplication(widget.applicationId);
    });
  }

  Future<void> _review(String status) async {
    if (_isSubmitting) return;

    try {
      setState(() => _isSubmitting = true);
      await _service.reviewManagerApplication(
        applicationId: widget.applicationId,
        status: status,
        notes: _notesController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application marked $status.')),
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
      title: 'Application Review',
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
            return const AdminEmptyState(message: 'Application not found.');
          }

          final payload = _payload(row);
          _notesController.text = _notesController.text.isEmpty
              ? _text(row['review_notes'], fallback: '')
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
                              _text(payload['name'], fallback: 'Unnamed hotel'),
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
                        label: 'Applicant',
                        value: _text(row['user_id']),
                      ),
                      AdminInfoRow(
                        label: 'Submitted',
                        value: _text(row['submitted_at']),
                      ),
                      AdminInfoRow(
                        label: 'Updated',
                        value: _text(row['updated_at']),
                      ),
                      AdminInfoRow(
                        label: 'Reviewed by',
                        value: _text(row['reviewed_by']),
                      ),
                    ],
                  ),
                ),
              ),
              const AdminSectionTitle(title: 'Property details'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      AdminInfoRow(label: 'Name', value: _text(payload['name'])),
                      AdminInfoRow(label: 'City', value: _text(payload['city'])),
                      AdminInfoRow(
                        label: 'Region',
                        value: _text(payload['region']),
                      ),
                      AdminInfoRow(
                        label: 'Country',
                        value: _text(payload['country']),
                      ),
                      AdminInfoRow(
                        label: 'Address',
                        value: _text(payload['address']),
                      ),
                      AdminInfoRow(
                        label: 'Rooms',
                        value: _text(payload['totalRooms']),
                      ),
                      AdminInfoRow(
                        label: 'Phone',
                        value: _text(payload['phoneNumber']),
                      ),
                      AdminInfoRow(label: 'Email', value: _text(payload['email'])),
                      AdminInfoRow(
                        label: 'Website',
                        value: _text(payload['website']),
                      ),
                    ],
                  ),
                ),
              ),
              const AdminSectionTitle(title: 'Review notes'),
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
                        _isSubmitting ? null : () => _review('under_review'),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Mark Under Review'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _review('approved'),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _review('rejected'),
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

  Map<String, dynamic> _payload(AdminRow row) {
    final payload = row['application_payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : {};
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
