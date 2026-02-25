import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/widgets/app_web_view.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/router/route_names.dart';
import '../../../../core/services/auth_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  
  // 1. Filtered roles to exclude Admin
  final roles = UserRole.values.where((role) => role != UserRole.systemAdmin).toList();
  UserRole selectedRole = UserRole.customer;
  
  bool _acceptedPolicy = false;
  bool _isLoading = false;
  final authService = AuthService();

  // Helper function to launch your Google Sites URL
  Future<void> _launchPrivacyUrl() async {
    Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const AppWebViewScreen(
        title: "Privacy Policy",
        url: 'https://sites.google.com/view/sokomtanda/privacy-policy',
      ),
    ),
  );
  }

  void signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Privacy Policy')),
      );
      return;
    }

    setState(() => _isLoading = true);
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
      // show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup successful! Taking you home.')),
      );
      if (mounted) context.go(RouteNames.splash);
    } catch (e) {
      ErrorReporter.report(e, StackTrace.current, source: 'ui.signup');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessageForError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color.fromARGB(255, 6, 101, 153);

    return Scaffold(
      backgroundColor: brandBlue, // 2. Applied requested background color
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hotel_rounded, size: 70, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text("Soko Mtandao", 
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildField(firstNameController, "First Name", Icons.person_outline),
                          const SizedBox(height: 15),
                          _buildField(lastNameController, "Last Name", Icons.person_outline),
                          const SizedBox(height: 15),
                          _buildField(emailController, "Email", Icons.email_outlined),
                          const SizedBox(height: 15),
                          _buildField(passwordController, "Password", Icons.lock_outline, obscure: true),
                          const SizedBox(height: 15),
                          
                          // 3. Refactored Dropdown
                          DropdownButtonFormField<UserRole>(
                            value: selectedRole,
                            items: roles.map((role) => DropdownMenuItem(
                              value: role, 
                              child: Text(role.name[0].toUpperCase() + role.name.substring(1)))
                            ).toList(),
                            onChanged: (val) => setState(() => selectedRole = val!),
                            decoration: const InputDecoration(
                              labelText: "Registering as",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // 4. Privacy Policy Checkbox
                          CheckboxListTile(
                            value: _acceptedPolicy,
                            onChanged: (val) => setState(() => _acceptedPolicy = val!),
                            contentPadding: EdgeInsets.zero,
                            title: Text.rich(
                              TextSpan(
                                text: "I agree to the ",
                                style: const TextStyle(fontSize: 13),
                                children: [
                                  TextSpan(
                                    text: "Privacy Policy",
                                    style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold),
                                    recognizer: TapGestureRecognizer()..onTap = _launchPrivacyUrl,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : const Text("SIGN UP", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => context.push(RouteNames.login),
                    child: const Text("Already have an account? Login", 
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  
                  // 5. Account Deletion Link (Required for Play Store)
                  TextButton(
                    onPressed: () {
                      // Navigate to your account deletion screen
                      context.pushNamed('deleteAccount', pathParameters: {'isManager': 'false'});
                    },
                    child: const Text("Need to delete an existing account?", 
                      style: TextStyle(color: Colors.white60, fontSize: 13, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
