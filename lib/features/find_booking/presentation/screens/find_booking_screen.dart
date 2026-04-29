import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_details.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_expiry_countdown.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';
import '../riverpod/find_booking_provider.dart';

class FindBookingScreen extends ConsumerStatefulWidget {
  const FindBookingScreen({super.key});

  @override
  ConsumerState<FindBookingScreen> createState() => _FindBookingScreenState();
}

class _FindBookingScreenState extends ConsumerState<FindBookingScreen> {
  final _controller = TextEditingController();
  String? _searchId; // Use a nullable string to toggle state

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _canLeaveReview(Booking booking) {
    return booking.status == BookingStatusEnum.confirmed &&
        booking.paymentStatus == PaymentStatusEnum.completed;
  }

  bool _canResumePayment(Booking booking) {
    final isPending = booking.status == BookingStatusEnum.pending &&
        booking.paymentStatus == PaymentStatusEnum.pending;
    if (!isPending) return false;
    if (booking.expiresAt == null) return true;
    return DateTime.now().isBefore(booking.expiresAt!);
  }

  Future<void> _openReviewDialog(Booking booking) async {
    if (!_canLeaveReview(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only confirmed stays can be rated.')),
      );
      return;
    }

    final commentCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        var rating = 5;
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitReview() async {
              setDialogState(() => submitting = true);
              try {
                final res = await Supabase.instance.client.rpc(
                  'submit_hotel_review',
                  params: {
                    'p_booking_id': booking.id,
                    'p_rating': rating,
                    'p_comment': commentCtrl.text.trim(),
                  },
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                final success =
                    res is Map<String, dynamic> && res['success'] == true;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Thank you. Your rating was submitted.'
                        : (res is Map<String, dynamic>
                            ? (res['message']?.toString() ??
                                'Failed to submit rating.')
                            : 'Failed to submit rating.')),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(userMessageForError(e))),
                );
              } finally {
                if (context.mounted) {
                  setDialogState(() => submitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Rate Your Stay'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: rating,
                    decoration: const InputDecoration(labelText: 'Rating'),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 - Excellent')),
                      DropdownMenuItem(value: 4, child: Text('4 - Very Good')),
                      DropdownMenuItem(value: 3, child: Text('3 - Good')),
                      DropdownMenuItem(value: 2, child: Text('2 - Fair')),
                      DropdownMenuItem(value: 1, child: Text('1 - Poor')),
                    ],
                    onChanged: submitting
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => rating = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submitReview,
                  child: submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _performSearch() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        _searchId = _controller.text.trim();
      });
      // Hide keyboard
      FocusScope.of(context).unfocus();
    }
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _searchId = null; // This triggers the switch back to History mode
    });
    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  Future<void> _openDisputeDialog(Booking booking) async {
    final ticket = (booking.ticketNumber ?? '').trim();
    if (ticket.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ticket number is required for disputes.')),
      );
      return;
    }

    final categoryCtrl = TextEditingController(text: 'general');
    final descriptionCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (descriptionCtrl.text.trim().isEmpty) return;
              setDialogState(() => submitting = true);
              try {
                await Supabase.instance.client.rpc('submit_dispute', params: {
                  'p_ticket_number': ticket,
                  'p_category': categoryCtrl.text.trim(),
                  'p_description': descriptionCtrl.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Dispute submitted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(userMessageForError(e))),
                  );
                }
              } finally {
                if (context.mounted) setDialogState(() => submitting = false);
              }
            }

            return AlertDialog(
              title: const Text('Submit Dispute'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Describe the issue',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch search result ONLY if we are searching
    final searchAsync =
        _searchId != null ? ref.watch(findBookingProvider(_searchId!)) : null;

    // Watch local history ONLY if we are NOT searching
    final historyAsync =
        _searchId == null ? ref.watch(localBookingHistoryProvider) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_searchId == null ? "My Bookings" : "Search Result"),
        actions: [
          const PersonaSwitcherButton(),
          // Optional: A refresh button for the history list
          if (_searchId == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.refresh(localBookingHistoryProvider),
            )
        ],
      ),
      body: Column(
        children: [
          // --- SEARCH BAR SECTION ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: "Search by Ticket Number",
                      hintText: "e.g., BK-20260228-123456",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      // Show clear button if there is text or an active search
                      suffixIcon:
                          (_controller.text.isNotEmpty || _searchId != null)
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearSearch,
                                )
                              : null,
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                  ),
                  child: const Text("Find"),
                ),
              ],
            ),
          ),

          // --- CONTENT SECTION (Switches between History and Search) ---
          Expanded(
            child: _searchId != null
                ? _buildSearchResults(searchAsync!)
                : _buildLocalHistory(historyAsync!),
          ),
        ],
      ),
    );
  }

  // --- Widget for Server Search Results ---
  Widget _buildSearchResults(AsyncValue searchAsync) {
    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userMessageForError(e))),
      data: (result) {
        if (!result.found) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "Ticket '$_searchId' not found.",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: _clearSearch,
                  child: const Text("Back to My History"),
                )
              ],
            ),
          );
        }
        // If found, show details
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookingDetailsWidget(booking: result.booking!),
              if (_canLeaveReview(result.booking!))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _openReviewDialog(result.booking!),
                    icon: const Icon(Icons.star_rate_outlined),
                    label: const Text('Rate This Stay'),
                  ),
                ),
              if (_canResumePayment(result.booking!))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context
                          .push('${RouteNames.payment}/${result.booking!.id}');
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume Payment'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- Widget for Local History ---
  Widget _buildLocalHistory(AsyncValue<List<Booking>> historyAsync) {
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userMessageForError(e))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_toggle_off,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("No saved bookings on this device."),
                const SizedBox(height: 8),
                const Text("Pending and confirmed bookings will appear here."),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: bookings.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.bookmark, color: Colors.white),
                    ),
                    title: Text(
                      "Ticket: ${(booking.ticketNumber ?? '').isNotEmpty ? booking.ticketNumber : booking.id}",
                    ),
                    // convert date to readable format
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((booking.ticketNumber ?? '').isNotEmpty)
                          Text("Ticket: ${booking.ticketNumber}"),
                        Text(
                            "Place: ${booking.bookingCart.bookings.first.hotel.name}"),
                        Text(
                            "Stay nights: ${formatYmd(booking.bookingCart.bookings.first.startDate)} to ${formatYmd(booking.bookingCart.bookings.first.endDate)}"),
                        if (booking.status == BookingStatusEnum.pending &&
                            booking.paymentStatus ==
                                PaymentStatusEnum.pending &&
                            booking.expiresAt != null)
                          BookingExpiryCountdown(
                            expiresAt: booking.expiresAt!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    isThreeLine: booking.status == BookingStatusEnum.pending &&
                        booking.paymentStatus == PaymentStatusEnum.pending &&
                        booking.expiresAt != null,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Pre-fill the search box and trigger search to get latest status
                      _controller.text = booking.ticketNumber ?? booking.id;
                      _performSearch();
                    },
                  ),
                  if (_canResumePayment(booking))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push('${RouteNames.payment}/${booking.id}');
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume Payment'),
                        ),
                      ),
                    ),
                  if (_canLeaveReview(booking))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _openReviewDialog(booking),
                          icon: const Icon(Icons.star_rate_outlined),
                          label: const Text('Rate Stay'),
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _openDisputeDialog(booking),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Submit Dispute'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
