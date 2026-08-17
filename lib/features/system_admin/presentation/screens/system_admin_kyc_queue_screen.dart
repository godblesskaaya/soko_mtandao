import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';
import 'package:soko_mtandao/router/route_names.dart';

class SystemAdminKycQueueScreen extends StatefulWidget {
  const SystemAdminKycQueueScreen({super.key});

  @override
  State<SystemAdminKycQueueScreen> createState() =>
      _SystemAdminKycQueueScreenState();
}

class _SystemAdminKycQueueScreenState extends State<SystemAdminKycQueueScreen> {
  final _service = SystemAdminService();
  late Future<List<AdminRow>> _future = _service.fetchKycQueue();

  void _refresh() {
    setState(() {
      _future = _service.fetchKycQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'KYC Review',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      child: AdminLoadView<List<AdminRow>>(
        future: _future,
        onRetry: _refresh,
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const AdminEmptyState(message: 'No KYC profiles need review.');
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                final userId = _text(row['user_id']);
                final status = _text(row['status'], fallback: 'pending');
                final name = _text(row['legal_name'], fallback: 'Unnamed user');
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(
                      'User: $userId\nUpdated: ${_text(row['updated_at'])}',
                    ),
                    isThreeLine: true,
                    leading: const Icon(Icons.verified_user_outlined),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AdminStatusChip(label: status),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.go(
                      '${RouteNames.systemAdminKycQueue}/$userId',
                    ),
                  ),
                );
              },
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
