import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/routes.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';
import '../onboarding/onboarding_screen.dart' show AuthScaffold;

/// Minimal password-reset flow.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _sent = true;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: _sent ? 'Check your inbox' : 'Reset your password',
      subtitle: _sent
          ? 'We sent a reset link to ${_emailController.text}. It expires in 15 minutes.'
          : 'Enter the email linked to your account and we\'ll send you a reset link.',
      footer: _sent
          ? CustomButton(
              label: 'Back to sign in',
              icon: Icons.login_rounded,
              onPressed: () => Nav.pop(context),
            )
          : CustomButton(
              label: 'Send reset link',
              isLoading: _isLoading,
              icon: Icons.send_rounded,
              onPressed: _send,
            ),
      children: [
        if (_sent) ...[
          const EmptyState(
            icon: Icons.mark_email_read_rounded,
            title: 'Link on its way',
            message:
                'Check your spam folder if it does not arrive within a few '
                'minutes.',
            compact: true,
          ),
          Gap.h16,
        ] else ...[
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 2),
                  child: Text(
                    'Email address',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                  ),
                  validator: Validators.email,
                ),
                Gap.h20,
                InfoBanner(
                  icon: Icons.info_rounded,
                  color: scheme.secondary,
                  title: 'Having trouble?',
                  message:
                      'Reach our support team at help@pethub.com and we will '
                      'get you back in within a few hours.',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
