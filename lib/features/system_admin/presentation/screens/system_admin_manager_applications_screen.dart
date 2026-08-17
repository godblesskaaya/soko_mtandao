import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';
import 'package:soko_mtandao/router/route_names.dart';

class SystemAdminManagerApplicationsScreen extends StatefulWidget {
  const SystemAdminManagerApplicationsScreen({super.key});

  @override
  State<SystemAdminManagerApplicationsScreen> createState() =>
      _SystemAdminManagerApplicationsScreenState();
}

class _SystemAdminManagerApplicationsScreenState
    extends State<SystemAdminManagerApplicationsScreen> {
  final _service = SystemAdminService();
  late Future<List<AdminRow>> _future = _service.fetchManagerApplications();

  void _refresh() {
    setState(() {
      _future = _service.fetchManagerApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Manager Applications',
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
            return const AdminEmptyState(
              message: 'No manager applications found.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                final applicationId = _text(row['id']);
                final payload = _payload(row);
                final name = _text(payload['name'], fallback: 'Unnamed hotel');
                final city = _text(payload['city']);
                final status = _text(row['status'], fallback: 'submitted');
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.business_center_outlined),
                    title: Text(name),
                    subtitle: Text(
                      'City: $city\nApplicant: ${_text(row['user_id'])}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AdminStatusChip(label: status),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.go(
                      '${RouteNames.systemAdminManagerApplications}/$applicationId',
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

  Map<String, dynamic> _payload(AdminRow row) {
    final payload = row['application_payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : {};
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
