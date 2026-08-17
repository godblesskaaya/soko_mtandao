import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPage extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget child;

  const AdminPage({
    super.key,
    required this.title,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: child,
    );
  }
}

class AdminLoadView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  const AdminLoadView({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  final String label;

  const AdminStatusChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(label);
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      backgroundColor: colors.$1,
      labelStyle: TextStyle(color: colors.$2, fontWeight: FontWeight.w600),
      side: BorderSide(color: colors.$2.withValues(alpha: 0.25)),
    );
  }

  (Color, Color) _colorsFor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'resolved':
      case 'processed':
        return (const Color(0xFFE6F4EA), const Color(0xFF137333));
      case 'rejected':
      case 'suspended':
      case 'breached':
        return (const Color(0xFFFCE8E6), const Color(0xFFC5221F));
      case 'under_review':
      case 'submitted':
        return (const Color(0xFFE8F0FE), const Color(0xFF174EA6));
      default:
        return (const Color(0xFFFFF7E0), const Color(0xFF8A5A00));
    }
  }
}

class AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String route;

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(label),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const AdminInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final String message;

  const AdminEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class AdminSectionTitle extends StatelessWidget {
  final String title;

  const AdminSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
