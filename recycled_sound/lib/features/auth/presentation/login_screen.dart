import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/rs_button.dart';

/// Login screen — email/password authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.hearing,
                      size: 32, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: Text('Welcome Back', style: AppTypography.h1)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Sign in to Recycled Sound',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 40),
              Text('Email', style: AppTypography.label),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
              const SizedBox(height: 20),
              Text('Password', style: AppTypography.label),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Enter password'),
              ),
              const SizedBox(height: 32),
              RsButton(
                label: 'Sign In',
                onPressed: () {
                  // Firebase Auth will be wired in Step 8
                  context.go('/');
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/signup'),
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      style: AppTypography.body,
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: AppTypography.button
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
