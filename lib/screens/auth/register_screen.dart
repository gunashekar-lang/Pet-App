import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../onboarding/onboarding_screen.dart' show AuthScaffold;

/// Multi-step registration flow with full form validation.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  double get _passwordStrength {
    final value = _passwordController.text;
    var score = 0.0;
    if (value.length >= 8) score += 0.34;
    if (RegExp(r'[A-Z]').hasMatch(value)) score += 0.22;
    if (RegExp(r'\d').hasMatch(value)) score += 0.22;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score += 0.22;
    return score.clamp(0.0, 1.0);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please fix the highlighted fields')),
        );
      return;
    }
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms and Privacy Policy'),
          ),
        );
      return;
    }

    final auth = context.read<AuthService>();
    final ok = await auth.register(
      fullName: _nameController.text,
      email: _emailController.text,
      phone: Validators.normalizeIndianPhone(_phoneController.text),
      password: _passwordController.text,
    );

    if (!mounted || !ok) return;
    HapticFeedback.mediumImpact();
    await Nav.resetTo(context, AppRoutes.shell);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLoading = context.select<AuthService, bool>((a) => a.isLoading);

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Join PetHub to buy, sell and get expert help for your pets.',
      footer: Column(
        children: [
          CustomButton(
            label: 'Create account',
            isLoading: isLoading,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: _submit,
          ),
          Gap.h12,
          Text(
            'By continuing you agree to our Terms of Service and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('Enter Your Full Name'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Enter Your Name',
                  prefixIcon: Icon(Icons.person_rounded, size: 20),
                ),
                validator: Validators.fullName,
              ),
              Gap.h16,
              const _Label('Email Address '),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Enter Your Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                ),
                validator: Validators.email,
              ),
              Gap.h16,
              const _Label('Phone number'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Enter Your Number',
                  prefixText: '+91  ',
                  prefixIcon: Icon(Icons.phone_rounded, size: 20),
                ),
                validator: Validators.phone,
                maxLength: 10,
              ),
              Gap.h16,
              const _Label('Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                  ),
                ),
                validator: Validators.password,
                onChanged: (_) => setState(() {}),
              ),
              Gap.h10,
              _StrengthBar(value: _passwordStrength),
              Gap.h16,
              const _Label('Confirm password'),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Re-enter your password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                  ),
                ),
                validator: (v) =>
                    Validators.confirmPassword(v, _passwordController.text),
                onFieldSubmitted: (_) => _submit(),
              ),
              Gap.h8,
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: Checkbox(
                      value: _acceptTerms,
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Gap.w8,
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Gap.h20,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account?',
              style: TextStyle(
                fontSize: 13.5,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            TextButton(
              onPressed: isLoading ? null : () => Nav.pop(context),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (value) {
      < 0.34 => ('Weak', AppColors.danger),
      < 0.67 => ('Fair', AppColors.warning),
      < 1.0 => ('Good', AppColors.mint),
      _ => ('Strong', AppColors.success),
    };

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        Gap.w10,
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
