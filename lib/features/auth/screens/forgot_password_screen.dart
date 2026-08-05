import 'package:flutter/material.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/state_views.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.sendPasswordResetEmail(
      _emailController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case Success():
        setState(() => _sent = true);
        AppSnackbar.success(context, 'Reset link sent! Check your inbox.');
      case Failure(:final message):
        AppSnackbar.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: AppColors.primaryBlue, size: 32),
                ),
                const SizedBox(height: 24),
                Text('Forgot Password?',
                    style: AppTextStyles.displayLarge(textColor)),
                const SizedBox(height: 8),
                Text(
                  _sent
                      ? 'We\'ve sent a password reset link to your email. Follow the instructions to reset your password.'
                      : 'Enter your email and we\'ll send you a link to reset your password.',
                  style: AppTextStyles.bodyMedium(bodyColor),
                ),
                const SizedBox(height: 32),
                if (!_sent) ...[
                  AppTextField(
                    controller: _emailController,
                    hintText: 'Email Address',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Send Reset Link',
                    isLoading: _isLoading,
                    onPressed: _handleReset,
                  ),
                ] else
                  SecondaryButton(
                    label: 'Back to Login',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
