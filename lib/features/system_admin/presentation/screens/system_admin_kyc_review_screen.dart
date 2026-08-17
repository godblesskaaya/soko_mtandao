import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';

class SystemAdminKycReviewScreen extends StatefulWidget {
  final String userId;

  const SystemAdminKycReviewScreen({super.key, required this.userId});

  @override
  State<SystemAdminKycReviewScreen> createState() =>
      _SystemAdminKycReviewScreenState();
}

class _SystemAdminKycReviewScreenState
    extends State<SystemAdminKycReviewScreen> {
  final _service = SystemAdminService();
  final _notesController = TextEditingController();
  late Future<AdminRow?> _future = _service.fetchKycProfile(widget.userId);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchKycProfile(widget.userId);
    });
  }

  Future<void> _setStatus(String status) async {
    if (_isSubmitting) return;

    try {
      setState(() => _isSubmitting = true);
      await _service.setKycStatus(
        userId: widget.userId,
        status: status,
        notes: _notesController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('KYC marked $status.')),
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
      title: 'KYC Detail',
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
            return const AdminEmptyState(message: 'KYC profile not found.');
          }

          final documents = List<Map<String, dynamic>>.from(
            row['kyc_documents'] as List? ?? const [],
          );
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
                              _text(row['legal_name'], fallback: 'Unnamed user'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          AdminStatusChip(
                            label: _text(row['status'], fallback: 'pending'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AdminInfoRow(label: 'User id', value: widget.userId),
                      AdminInfoRow(
                        label: 'National ID',
                        value: _text(row['national_id']),
                      ),
                      AdminInfoRow(
                        label: 'Date of birth',
                        value: _text(row['date_of_birth']),
                      ),
                      AdminInfoRow(
                        label: 'Address',
                        value: _text(row['physical_address']),
                      ),
                      AdminInfoRow(
                        label: 'Phone verified',
                        value: (row['phone_verified'] == true).toString(),
                      ),
                      AdminInfoRow(
                        label: 'Submitted',
                        value: _text(row['submitted_at']),
                      ),
                      AdminInfoRow(
                        label: 'Updated',
                        value: _text(row['updated_at']),
                      ),
                    ],
                  ),
                ),
              ),
              const AdminSectionTitle(title: 'Documents'),
              if (documents.isEmpty)
                const Text('No documents attached.')
              else
                ...documents.map(
                  (doc) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(_text(doc['document_type'])),
                    subtitle: Text(_text(doc['document_url'])),
                  ),
                ),
              const AdminSectionTitle(title: 'Decision notes'),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Admin notes',
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
                        _isSubmitting ? null : () => _setStatus('approved'),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _setStatus('rejected'),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isSubmitting ? null : () => _setStatus('suspended'),
                    icon: const Icon(Icons.block),
                    label: const Text('Suspend'),
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
