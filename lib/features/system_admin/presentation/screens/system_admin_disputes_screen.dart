import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';
import 'package:soko_mtandao/router/route_names.dart';

class SystemAdminDisputesScreen extends StatefulWidget {
  const SystemAdminDisputesScreen({super.key});

  @override
  State<SystemAdminDisputesScreen> createState() =>
      _SystemAdminDisputesScreenState();
}

class _SystemAdminDisputesScreenState extends State<SystemAdminDisputesScreen> {
  final _service = SystemAdminService();
  late Future<List<AdminRow>> _future = _service.fetchDisputes();

  void _refresh() {
    setState(() {
      _future = _service.fetchDisputes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Disputes',
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
            return const AdminEmptyState(message: 'No active disputes.');
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                final disputeId = _text(row['id']);
                final status = _text(row['status'], fallback: 'submitted');
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.report_problem_outlined),
                    title: Text('Ticket ${_text(row['ticket_number'])}'),
                    subtitle: Text(
                      '${_text(row['category'])}\nSLA: ${_text(row['sla_due_at'])}',
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
                      '${RouteNames.systemAdminDisputes}/$disputeId',
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
