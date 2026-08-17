import 'package:supabase_flutter/supabase_flutter.dart';

typedef AdminRow = Map<String, dynamic>;

class SystemAdminSnapshot {
  final List<AdminRow> kycQueue;
  final List<AdminRow> managerApplications;
  final List<AdminRow> activeFreezes;
  final List<AdminRow> disputes;
  final List<AdminRow> refundSla;
  final List<AdminRow> investigations;
  final int retentionDays;

  const SystemAdminSnapshot({
    required this.kycQueue,
    required this.managerApplications,
    required this.activeFreezes,
    required this.disputes,
    required this.refundSla,
    required this.investigations,
    required this.retentionDays,
  });

  int get breachedRefunds =>
      refundSla.where((row) => row['is_breached'] == true).length;
}

class SystemAdminService {
  SystemAdminService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SystemAdminSnapshot> fetchSnapshot() async {
    final results = await Future.wait<dynamic>([
      fetchKycQueue(),
      fetchManagerApplications(),
      fetchActiveFreezes(),
      fetchDisputes(),
      fetchRefundSla(),
      fetchInvestigations(),
      fetchRetentionDays(),
    ]);

    return SystemAdminSnapshot(
      kycQueue: List<AdminRow>.from(results[0] as List),
      managerApplications: List<AdminRow>.from(results[1] as List),
      activeFreezes: List<AdminRow>.from(results[2] as List),
      disputes: List<AdminRow>.from(results[3] as List),
      refundSla: List<AdminRow>.from(results[4] as List),
      investigations: List<AdminRow>.from(results[5] as List),
      retentionDays: results[6] as int,
    );
  }

  Future<List<AdminRow>> fetchKycQueue() async {
    final rows = await _client
        .from('kyc_profiles')
        .select(
          'id,user_id,legal_name,status,phone_verified,submitted_at,updated_at,review_notes',
        )
        .inFilter('status', ['submitted', 'pending', 'rejected', 'suspended'])
        .order('updated_at', ascending: false)
        .limit(80);
    return _rows(rows);
  }

  Future<AdminRow?> fetchKycProfile(String userId) async {
    final row = await _client
        .from('kyc_profiles')
        .select(
          'id,user_id,legal_name,national_id,date_of_birth,physical_address,phone_verified,status,submitted_at,approved_at,rejected_at,suspended_at,review_notes,metadata,created_at,updated_at,kyc_documents(id,document_type,document_url,created_at)',
        )
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> setKycStatus({
    required String userId,
    required String status,
    required String notes,
  }) {
    return _client.rpc('set_kyc_status', params: {
      'p_user_id': userId,
      'p_status': status,
      'p_notes': notes.trim(),
    });
  }

  Future<List<AdminRow>> fetchManagerApplications() async {
    final rows = await _client
        .from('operator_applications')
        .select(
          'id,user_id,status,submitted_at,reviewed_at,updated_at,review_notes,application_payload',
        )
        .order('updated_at', ascending: false)
        .limit(80);
    return _rows(rows);
  }

  Future<AdminRow?> fetchManagerApplication(String applicationId) async {
    final row = await _client
        .from('operator_applications')
        .select(
          'id,user_id,status,submitted_at,reviewed_at,reviewed_by,updated_at,review_notes,application_payload',
        )
        .eq('id', applicationId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> reviewManagerApplication({
    required String applicationId,
    required String status,
    required String notes,
  }) {
    return _client.rpc('review_manager_application', params: {
      'p_application_id': applicationId,
      'p_status': status,
      'p_review_notes': notes.trim(),
    });
  }

  Future<List<AdminRow>> fetchDisputes() async {
    final rows = await _client
        .from('disputes')
        .select(
          'id,booking_id,ticket_number,submitted_by,status,category,description,admin_notes,sla_due_at,resolved_at,created_at,updated_at',
        )
        .inFilter('status', ['submitted', 'under_review'])
        .order('created_at', ascending: false)
        .limit(80);
    return _rows(rows);
  }

  Future<AdminRow?> fetchDispute(String disputeId) async {
    final row = await _client
        .from('disputes')
        .select(
          'id,booking_id,ticket_number,submitted_by,status,category,description,admin_notes,sla_due_at,resolved_at,created_at,updated_at',
        )
        .eq('id', disputeId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> setDisputeStatus({
    required String disputeId,
    required String status,
    required String notes,
  }) {
    return _client.rpc('set_dispute_status', params: {
      'p_dispute_id': disputeId,
      'p_status': status,
      'p_admin_notes': notes.trim(),
    });
  }

  Future<List<AdminRow>> fetchActiveFreezes() async {
    final rows = await _client
        .from('account_freezes')
        .select('id,user_id,reason,set_by,started_at,is_active,updated_at')
        .eq('is_active', true)
        .order('started_at', ascending: false)
        .limit(80);
    return _rows(rows);
  }

  Future<void> setAccountFreeze({
    required String userId,
    required bool isFrozen,
    required String reason,
  }) {
    return _client.rpc('set_account_freeze', params: {
      'p_user_id': userId,
      'p_is_frozen': isFrozen,
      'p_reason': reason.trim(),
    });
  }

  Future<int> fetchRetentionDays() async {
    final row = await _client
        .from('compliance_settings')
        .select('value_int')
        .eq('key', 'audit_log_retention_days')
        .maybeSingle();
    return (row?['value_int'] as num?)?.toInt() ?? 2555;
  }

  Future<void> setRetentionDays(int days) {
    return _client.rpc('set_retention_policy_days', params: {'p_days': days});
  }

  Future<List<AdminRow>> fetchRefundSla() async {
    final rows = await _client
        .from('refund_sla_tracker_view')
        .select(
          'id,booking_id,payment_id,amount,currency,status,created_at,processed_at,sla_due_at,is_breached',
        )
        .order('sla_due_at', ascending: true)
        .limit(80);
    return _rows(rows);
  }

  Future<List<AdminRow>> fetchInvestigations() async {
    final rows = await _client
        .from('admin_investigation_queue_view')
        .select('id,event_type,entity_type,entity_id,actor_user_id,payload,created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return _rows(rows);
  }

  List<AdminRow> _rows(dynamic value) {
    return List<Map<String, dynamic>>.from(value as List);
  }
}
