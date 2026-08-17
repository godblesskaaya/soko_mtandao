import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/system_admin/data/system_admin_service.dart';
import 'package:soko_mtandao/features/system_admin/presentation/widgets/admin_widgets.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';

class SystemAdminDashboardScreen extends StatefulWidget {
  const SystemAdminDashboardScreen({super.key});

  @override
  State<SystemAdminDashboardScreen> createState() =>
      _SystemAdminDashboardScreenState();
}

class _SystemAdminDashboardScreenState
    extends State<SystemAdminDashboardScreen> {
  final _service = SystemAdminService();
  late Future<SystemAdminSnapshot> _future = _service.fetchSnapshot();

  void _refresh() {
    setState(() {
      _future = _service.fetchSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'System Admin',
      actions: [
        const PersonaSwitcherButton(),
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
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Operations dashboard',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Review operational queues, compliance risk, and account controls.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    return GridView.count(
                      crossAxisCount: wide ? 2 : 1,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: wide ? 4.4 : 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        AdminMetricCard(
                          label: 'KYC requiring review',
                          value: snapshot.kycQueue.length.toString(),
                          icon: Icons.verified_user_outlined,
                          route: RouteNames.systemAdminKycQueue,
                        ),
                        AdminMetricCard(
                          label: 'Manager applications',
                          value: snapshot.managerApplications.length.toString(),
                          icon: Icons.business_center_outlined,
                          route: RouteNames.systemAdminManagerApplications,
                        ),
                        AdminMetricCard(
                          label: 'Open disputes',
                          value: snapshot.disputes.length.toString(),
                          icon: Icons.report_problem_outlined,
                          route: RouteNames.systemAdminDisputes,
                        ),
                        AdminMetricCard(
                          label: 'Active account freezes',
                          value: snapshot.activeFreezes.length.toString(),
                          icon: Icons.lock_person_outlined,
                          route: RouteNames.systemAdminAccounts,
                        ),
                        AdminMetricCard(
                          label: 'Refund SLA breaches',
                          value: snapshot.breachedRefunds.toString(),
                          icon: Icons.timer_off_outlined,
                          route: RouteNames.systemAdminCompliance,
                        ),
                        AdminMetricCard(
                          label: 'Flagged investigation events',
                          value: snapshot.investigations.length.toString(),
                          icon: Icons.manage_search_outlined,
                          route: RouteNames.systemAdminCompliance,
                        ),
                      ],
                    );
                  },
                ),
                const AdminSectionTitle(title: 'Operating policy'),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminInfoRow(
                          label: 'Audit retention',
                          value: '${snapshot.retentionDays} days',
                        ),
                        const AdminInfoRow(
                          label: 'Admin actions',
                          value:
                              'KYC, manager reviews, disputes, account freezes, and retention changes are audited by backend RPCs.',
                        ),
                      ],
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
}
