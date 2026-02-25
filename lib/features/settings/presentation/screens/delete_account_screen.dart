import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  final bool isManager;

  const DeleteAccountScreen({super.key, required this.isManager});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState
    extends ConsumerState<DeleteAccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delete Account & Data")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isManager
                  ? "Delete Manager Account"
                  : "Clear Personal Data",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isManager
                  ? "Deleting your account will permanently remove your hotel listings, management access, and personal profile from our database."
                  : "This will remove your booking history and contact details from this device. We keep transaction records for legal purposes as required by tax law.",
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _confirmDeletion(context),
                child: Text(
                  widget.isManager
                      ? "Permanently Delete My Account"
                      : "Clear My Data",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Are you absolutely sure?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              if (widget.isManager) {
                _deleteManagerAccount(context);
              } else {
                _clearGuestData(context);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _clearGuestData(BuildContext context) async {
    await ref.read(localBookingStorageProvider).clearHistory();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Local history and data cleared.")),
    );

    context.go('/home');
  }

  Future<void> _deleteManagerAccount(BuildContext context) async {
    final supabase = Supabase.instance.client;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator()),
      );

      await supabase.functions.invoke(
        'delete-user',
        method: HttpMethod.post,
      );

      if (context.mounted) Navigator.pop(context);

      await supabase.auth.signOut();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account successfully deleted.")),
      );

      context.goNamed('guestHome');
    } on FunctionException catch (e) {
      if (context.mounted) Navigator.pop(context);
      ErrorReporter.report(e, StackTrace.current, source: 'ui.delete_account.function');
      _showErrorSnackBar(context, userMessageForError(e));
    } catch (e, stackTrace) {
      if (context.mounted) Navigator.pop(context);
      ErrorReporter.report(e, stackTrace, source: 'ui.delete_account');
      _showErrorSnackBar(context, "An unexpected error occurred. Please try again.");
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
