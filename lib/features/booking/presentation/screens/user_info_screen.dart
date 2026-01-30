import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_providers.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';

class UserInfoScreen extends ConsumerStatefulWidget {
  const UserInfoScreen({super.key});

  @override
  ConsumerState<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends ConsumerState<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(bookingCartProvider);
    final flow = ref.watch(bookingFlowProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: cart.isEmpty
            ? const Center(child: Text('Your cart is empty.'))
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      // validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(v!)) return 'Invalid email';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                        if (!phoneRegex.hasMatch(v)) return 'Invalid phone number';
                        return null;
                        },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: flow.isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;

                              final id = await ref
                                  .read(bookingFlowProvider.notifier)
                                  .initiate(
                                    user: UserInfo(
                                      name: nameCtrl.text.trim(),
                                      email: emailCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim(),
                                    ),
                                  );

                              // print the id for debugging
                              print('Booking initiated with ID: $id');

                              if (id != null && mounted) {
                                // Optionally clear cart after successful initiation
                                // ref.read(bookingCartProvider.notifier).clearCart();
                                context.push('${RouteNames.bookingReview}/$id');
                              } else {
                                // get the error from the notifier and display it
                                final error = ref.read(bookingFlowProvider.notifier).state.error;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text((error ?? 'Failed to create booking').toString())),
                                );
                              }
                            },
                      child: flow.isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Review Booking'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
