import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';

class SystemAdminDashboardScreen extends StatefulWidget {
  const SystemAdminDashboardScreen({super.key});

  @override
  State<SystemAdminDashboardScreen> createState() =>
      _SystemAdminDashboardScreenState();
}

class _SystemAdminDashboardScreenState
    extends State<SystemAdminDashboardScreen> {
  final _freezeUserIdCtrl = TextEditingController();
  final _freezeReasonCtrl = TextEditingController();
  final _retentionDaysCtrl = TextEditingController();

  bool _isLoading = true;
  Map<String, dynamic> _snapshot = const <String, dynamic>{};

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final kycQueue = await _client
          .from('kyc_profiles')
          .select('user_id,legal_name,status,submitted_at,updated_at')
          .inFilter('status', ['submitted', 'pending', 'rejected', 'suspended'])
          .order('updated_at', ascending: false)
          .limit(40);

      final managerApplications = await _client
          .from('operator_applications')
          .select(
              'id,user_id,status,submitted_at,updated_at,review_notes,application_payload')
          .order('updated_at', ascending: false)
          .limit(40);

      final freezes = await _client
          .from('account_freezes')
          .select('user_id,reason,started_at,is_active')
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(40);

      final disputes = await _client
          .from('disputes')
          .select(
              'id,ticket_number,status,category,created_at,sla_due_at,description')
          .inFilter('status', ['submitted', 'under_review'])
          .order('created_at', ascending: false)
          .limit(40);

      final refundsSla = await _client
          .from('refund_sla_tracker_view')
          .select('id,booking_id,status,sla_due_at,is_breached')
          .order('sla_due_at', ascending: true)
          .limit(40);

      final investigations = await _client
          .from('admin_investigation_queue_view')
          .select('id,event_type,entity_type,entity_id,created_at,payload')
          .order('created_at', ascending: false)
          .limit(60);

      final retention = await _client
          .from('compliance_settings')
          .select('value_int')
          .eq('key', 'audit_log_retention_days')
          .maybeSingle();

      _retentionDaysCtrl.text = (retention?['value_int'] ?? 2555).toString();

      _snapshot = {
        'kyc': kycQueue,
        'managerApplications': managerApplications,
        'freezes': freezes,
        'disputes': disputes,
        'refunds': refundsSla,
        'investigations': investigations,
      };
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setKycStatus(String userId, String status) async {
    await _client.rpc('set_kyc_status', params: {
      'p_user_id': userId,
      'p_status': status,
      'p_notes': 'Set from admin dashboard',
    });
    await _load();
  }

  Future<void> _setManagerApplicationStatus(
      String applicationId, String status) async {
    await _client.rpc('review_manager_application', params: {
      'p_application_id': applicationId,
      'p_status': status,
      'p_review_notes': 'Updated from admin dashboard',
    });
    await _load();
  }

  Future<void> _setDisputeStatus(String disputeId, String status) async {
    await _client.rpc('set_dispute_status', params: {
      'p_dispute_id': disputeId,
      'p_status': status,
      'p_admin_notes': 'Updated from admin dashboard',
    });
    await _load();
  }

  Future<void> _setFreeze(bool freeze) async {
    final userId = _freezeUserIdCtrl.text.trim();
    if (userId.isEmpty) {
      throw Exception('Provide a user ID');
    }

    await _client.rpc('set_account_freeze', params: {
      'p_user_id': userId,
      'p_is_frozen': freeze,
      'p_reason': _freezeReasonCtrl.text.trim(),
    });

    await _load();
  }

  Future<void> _setRetention() async {
    final days = int.tryParse(_retentionDaysCtrl.text.trim());
    if (days == null) throw Exception('Retention must be a number');

    await _client.rpc('set_retention_policy_days', params: {'p_days': days});
    await _load();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Action completed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  void dispose() {
    _freezeUserIdCtrl.dispose();
    _freezeReasonCtrl.dispose();
    _retentionDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kyc = List<Map<String, dynamic>>.from(_snapshot['kyc'] ?? const []);
    final managerApplications = List<Map<String, dynamic>>.from(
      _snapshot['managerApplications'] ?? const [],
    );
    final freezes =
        List<Map<String, dynamic>>.from(_snapshot['freezes'] ?? const []);
    final disputes =
        List<Map<String, dynamic>>.from(_snapshot['disputes'] ?? const []);
    final refunds =
        List<Map<String, dynamic>>.from(_snapshot['refunds'] ?? const []);
    final investigations = List<Map<String, dynamic>>.from(
      _snapshot['investigations'] ?? const [],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Admin Dashboard'),
        actions: [
          const PersonaSwitcherButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _runAction(_load),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('KYC Queue: ${kyc.length}')),
                      Chip(
                        label: Text(
                            'Manager Apps: ${managerApplications.length}'),
                      ),
                      Chip(label: Text('Frozen: ${freezes.length}')),
                      Chip(label: Text('Disputes: ${disputes.length}')),
                      Chip(
                        label: Text(
                          'Refund SLA Breach: ${refunds.where((r) => r['is_breached'] == true).length}',
                        ),
                      ),
                    ],
                  ),
                  _sectionTitle('Retention Policy'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _retentionDaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Audit Retention (days)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () => _runAction(_setRetention),
                              child: const Text('Update Retention'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _sectionTitle('Account Freeze Controls'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _freezeUserIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Target User ID',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _freezeReasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _runAction(() => _setFreeze(true)),
                                  child: const Text('Freeze'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _runAction(() => _setFreeze(false)),
                                  child: const Text('Unfreeze'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _sectionTitle('KYC Queue'),
                  if (kyc.isEmpty)
                    const Text('No KYC profiles pending action.')
                  else
                    ...kyc.map((row) {
                      final userId = row['user_id']?.toString() ?? '';
                      final status = row['status']?.toString() ?? 'pending';
                      final name = row['legal_name']?.toString().trim();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name == null || name.isEmpty
                                  ? userId
                                  : '$name ($userId)'),
                              const SizedBox(height: 4),
                              Text('Status: $status'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _runAction(() =>
                                        _setKycStatus(userId, 'approved')),
                                    child: const Text('Approve'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _runAction(() =>
                                        _setKycStatus(userId, 'rejected')),
                                    child: const Text('Reject'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _runAction(() =>
                                        _setKycStatus(userId, 'suspended')),
                                    child: const Text('Suspend'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  _sectionTitle('Manager Applications'),
                  if (managerApplications.isEmpty)
                    const Text('No manager applications pending review.')
                  else
                    ...managerApplications.map((row) {
                      final applicationId = row['id']?.toString() ?? '';
                      final status = row['status']?.toString() ?? '-';
                      final rawPayload = row['application_payload'];
                      final payload = rawPayload is Map
                          ? Map<String, dynamic>.from(
                              rawPayload,
                            )
                          : const <String, dynamic>{};
                      final hotelName =
                          (payload['name'] ?? 'Unnamed hotel').toString();
                      final hotelCity = (payload['city'] ?? '-').toString();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$hotelName - $hotelCity'),
                              const SizedBox(height: 4),
                              Text('Applicant: ${row['user_id'] ?? '-'}'),
                              Text('Status: $status'),
                              if ((row['review_notes'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text('Notes: ${row['review_notes']}'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _runAction(() =>
                                        _setManagerApplicationStatus(
                                            applicationId, 'under_review')),
                                    child: const Text('Mark Under Review'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _runAction(() =>
                                        _setManagerApplicationStatus(
                                            applicationId, 'approved')),
                                    child: const Text('Approve'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _runAction(() =>
                                        _setManagerApplicationStatus(
                                            applicationId, 'rejected')),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  _sectionTitle('Dispute Queue'),
                  if (disputes.isEmpty)
                    const Text('No active disputes.')
                  else
                    ...disputes.map((row) {
                      final disputeId = row['id']?.toString() ?? '';
                      final ticket = row['ticket_number']?.toString() ?? '-';
                      final status = row['status']?.toString() ?? '-';
                      final category = row['category']?.toString() ?? '-';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ticket: $ticket | Category: $category'),
                              Text('Status: $status'),
                              const SizedBox(height: 6),
                              Text(
                                row['description']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _runAction(
                                      () => _setDisputeStatus(
                                          disputeId, 'under_review'),
                                    ),
                                    child: const Text('Mark Under Review'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _runAction(
                                      () => _setDisputeStatus(
                                          disputeId, 'resolved'),
                                    ),
                                    child: const Text('Resolve'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _runAction(
                                      () => _setDisputeStatus(
                                          disputeId, 'rejected'),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  _sectionTitle('Refund SLA Tracker'),
                  if (refunds.isEmpty)
                    const Text('No refund SLA records.')
                  else
                    ...refunds.map((row) {
                      final isBreached = row['is_breached'] == true;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Refund ${row['id']}'),
                        subtitle: Text('Due: ${row['sla_due_at'] ?? '-'}'),
                        trailing: Text(
                          isBreached ? 'BREACHED' : 'OK',
                          style: TextStyle(
                            color: isBreached ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  _sectionTitle('Investigation Queue'),
                  if (investigations.isEmpty)
                    const Text('No flagged events.')
                  else
                    ...investigations.map((row) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${row['event_type']} - ${row['entity_type']}'),
                        subtitle: Text(
                          '${row['entity_id'] ?? ''}\n${row['created_at'] ?? ''}',
                        ),
                        isThreeLine: true,
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
