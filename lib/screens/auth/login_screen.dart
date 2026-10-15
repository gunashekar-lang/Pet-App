import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';
import '../onboarding/onboarding_screen.dart' show AuthScaffold;

/// Sign-in screen. Accounts are created locally until the authentication
/// backend is connected.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthService>();
    final ok = await auth.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      await Nav.resetTo(context, AppRoutes.shell);
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(auth.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLoading = context.select<AuthService, bool>((a) => a.isLoading);

    return AuthScaffold(
      title: 'Welcome back 👋',
      subtitle:
          'Sign in to continue browsing pets, managing listings and '
          'tracking orders.',
      footer: Column(
        children: [
          CustomButton(
            label: 'Sign in',
            isLoading: isLoading,
            icon: Icons.login_rounded,
            onPressed: _submit,
          ),
          Gap.h16,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'New to PetHub?',
                style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Nav.push(context, AppRoutes.register),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Email or mobile number'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Email or Phone',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                ),
                validator: Validators.emailOrPhone,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              Gap.h20,
              const _FieldLabel('Password'),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
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
                onFieldSubmitted: (_) => _submit(),
              ),
              Gap.h8,
              Row(
                children: [
                  SizedBox(
                    height: 32,
                    width: 32,
                    child: Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Gap.w8,
                  Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        Nav.push(context, AppRoutes.forgotPassword),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              Gap.h12,
              InfoBanner(
                icon: Icons.info_outline_rounded,
                color: AppColors.accent,
                title: 'Accounts are local for now',
                message:
                    'Signing in needs the PetHub backend, which is not connected '
                    'yet. Create an account to explore the app.',
              ),
            ],
          ),
        ),
        Gap.h24,
        Row(
          children: [
            Expanded(child: Divider(color: scheme.outline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(child: Divider(color: scheme.outline)),
          ],
        ),
        Gap.h20,
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                icon: Icons.g_mobiledata_rounded,
                onTap: isLoading ? null : () => _socialLogin(),
              ),
            ),
           
          ],
        ),
        Gap.h24,
        const _TrustRow(),
      ],
    );
  }

  Future<void> _socialLogin() async {
    final auth = context.read<AuthService>();
    final ok = await auth.loginWithGoogle();
    if (!mounted || !ok) return;
    HapticFeedback.mediumImpact();
    await Nav.resetTo(context, AppRoutes.shell);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        side: BorderSide(color: scheme.outline),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.lock_rounded, 'Secure'),
      (Icons.verified_rounded, 'Verified sellers'),
      (Icons.support_agent_rounded, '24/7 support'),
    ];

    return Helpers.centerContent(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            Gap.w8,
            Icon(
              items[i].$1,
              size: 14,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
            Gap.w4,
            Text(
              items[i].$2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
