import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/router/route_names.dart';
import '../../../../core/services/auth_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final authService = AuthService();
  final roles = [UserRole.customer, UserRole.hotelAdmin, UserRole.staff,];
  UserRole selectedRole = UserRole.customer;

  void signup() async {
    try {
      await authService.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
                'role': selectedRole.name,
                'firstName': firstNameController.text.trim(),
                'lastName': lastNameController.text.trim(),
              },
      );

      
      if (mounted) context.go(RouteNames.splash); // Navigate to splash screen after signup
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
            TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            DropdownButtonFormField<UserRole>(items: roles.map((role) => DropdownMenuItem(value: role,
                                              child: Text(role.name))).toList(),
                                              onChanged: (val) {
                                                if (val != null) setState(() => selectedRole =val);
                                              },
                                              decoration: const InputDecoration(labelText: 'How do you want to be recognized'),
                                              ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: signup, child: const Text('Sign Up')),
                        TextButton(
              onPressed: () {
                context.go(RouteNames.login); // Navigate to login screen
              },
              child: const Text('Have an account? Login'),
            ),

          ],
        ),
      ),
    );
  }
}
