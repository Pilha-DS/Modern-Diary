import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import 'auth_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller, required this.toat});

  final AuthController controller;
  final ToatController toat;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    if (widget.controller.isSubmitting) {
      return;
    }
    widget.controller.clearError();
    _passwordController.clear();
    setState(() => _registerMode = !_registerMode);
  }

  Future<void> _submit() async {
    if (widget.controller.isSubmitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final registering = _registerMode;
    final success = registering
        ? await widget.controller.register(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          )
        : await widget.controller.login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );

    if (!success) {
      return;
    }

    TextInput.finishAutofillContext();
    widget.toat.show(
      registering ? AppStrings.registerSuccess : AppStrings.loginSuccess,
      variant: ToatVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxFormWidth,
                ),
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final controller = widget.controller;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final usernameError = controller.fieldErrors['username'];
    final passwordError = controller.fieldErrors['password'];
    final showGeneralError =
        controller.error != null && controller.fieldErrors.isEmpty;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(semanticLabel: AppStrings.appName),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.appName, style: textTheme.titleLarge),
                        Text(
                          AppStrings.appTagline,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _registerMode
                    ? AppStrings.registerTitle
                    : AppStrings.loginTitle,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _registerMode
                    ? AppStrings.registerSubtitle
                    : AppStrings.loginSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (showGeneralError) ...[
                InlineMessage(
                  message: controller.error!.message,
                  variant: InlineMessageVariant.error,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                controller: _usernameController,
                label: AppStrings.usernameLabel,
                hint: AppStrings.usernameHint,
                showPasswordLabel: AppStrings.showPassword,
                hidePasswordLabel: AppStrings.hidePassword,
                prefixIcon: Icons.person_outline_rounded,
                enabled: !controller.isSubmitting,
                errorText: usernameError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: (_) => controller.clearError(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppStrings.usernameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _passwordController,
                label: AppStrings.passwordLabel,
                hint: AppStrings.passwordHint,
                showPasswordLabel: AppStrings.showPassword,
                hidePasswordLabel: AppStrings.hidePassword,
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                enabled: !controller.isSubmitting,
                errorText: passwordError,
                textInputAction: TextInputAction.done,
                autofillHints: [
                  _registerMode
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onChanged: (_) => controller.clearError(),
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppStrings.passwordRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _registerMode ? AppStrings.register : AppStrings.login,
                onPressed: _submit,
                isLoading: controller.isSubmitting,
                expanded: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _registerMode
                          ? AppStrings.switchToLoginQuestion
                          : AppStrings.switchToRegisterQuestion,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.isSubmitting ? null : _toggleMode,
                    child: Text(
                      _registerMode
                          ? AppStrings.switchToLoginAction
                          : AppStrings.switchToRegisterAction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
