import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/password_strength_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../widgets/social_sign_in_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.registerWithEmail(
      fullName: _nameController.text.trim(),
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case Success():
        AppSnackbar.success(context, 'Account created! Welcome to EduSphere.');
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home, (route) => false);
      case Failure(:final message):
        AppSnackbar.error(context, message);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final result = await _authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    switch (result) {
      case Success():
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home, (route) => false);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Text('Create Account',
                    style: AppTextStyles.displayLarge(textColor)),
                const SizedBox(height: 8),
                Text(
                  'Join EduSphere and start learning today.',
                  style: AppTextStyles.bodyMedium(bodyColor),
                ),
                const SizedBox(height: 28),
                SocialSignInButton(
                  label: 'Continue with Google',
                  icon: Icons.g_mobiledata_rounded,
                  isLoading: _isGoogleLoading,
                  onPressed: _handleGoogleSignIn,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: AppTextStyles.bodySmall(bodyColor)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  hintText: 'Full Name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => Validators.required(v, field: 'Full name'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  hintText: 'Email Address',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: Validators.password,
                  onChanged: (_) => setState(() {}),
                ),
                PasswordStrengthBar(password: _passwordController.text),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmController,
                  hintText: 'Confirm Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (v) => Validators.confirmPassword(
                      v, _passwordController.text),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Sign Up',
                  isLoading: _isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: AppTextStyles.bodyMedium(bodyColor)),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.login),
                        child: Text(
                          'Login',
                          style: AppTextStyles.bodyMedium(AppColors.primaryBlue)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
