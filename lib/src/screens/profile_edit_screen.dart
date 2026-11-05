import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../labels.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.controller,
    this.initialSetup = false,
    this.onSaved,
    this.onLogout,
  });

  final AppController controller;
  final bool initialSetup;
  final VoidCallback? onSaved;
  final VoidCallback? onLogout;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _lastName = TextEditingController(
    text: widget.controller.lastName ?? '',
  );
  late final _firstName = TextEditingController(
    text: widget.controller.firstName ?? '',
  );
  late final _middleName = TextEditingController(
    text: widget.controller.middleName ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _middleName.dispose();
    super.dispose();
  }

  String? _validate(String? value, {String? requiredMessage}) {
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return requiredMessage;
    if (normalized.runes.length > 80) return context.l10n.nameTooLong;
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.updateProfileName(
        firstName: _firstName.text,
        lastName: _lastName.text,
        middleName: _middleName.text,
      );
      if (!mounted || (widget.initialSetup && !widget.controller.isSignedIn)) {
        return;
      }
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorTextFor(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !widget.initialSetup,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.initialSetup,
          title: Text(
            widget.initialSetup ? l10n.introduceYourself : l10n.personalData,
          ),
          actions: [
            if (widget.initialSetup && widget.onLogout != null)
              TextButton(
                key: const ValueKey('profile-setup-logout'),
                onPressed: _saving ? null : widget.onLogout,
                child: Text(l10n.logoutConfirm),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.initialSetup
                          ? l10n.firstLoginNameHint
                          : l10n.profileNameHint,
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('profile-last-name'),
                      controller: _lastName,
                      enabled: !_saving,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: InputDecoration(
                        labelText: l10n.lastNameLabel,
                      ),
                      validator: (value) => _validate(
                        value,
                        requiredMessage: l10n.lastNameRequired,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('profile-first-name'),
                      controller: _firstName,
                      enabled: !_saving,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: InputDecoration(
                        labelText: l10n.firstNameLabel,
                      ),
                      validator: (value) => _validate(
                        value,
                        requiredMessage: l10n.firstNameRequired,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('profile-middle-name'),
                      controller: _middleName,
                      enabled: !_saving,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.middleName],
                      decoration: InputDecoration(
                        labelText: l10n.middleNameLabel,
                        helperText: l10n.middleNameOptional,
                      ),
                      validator: _validate,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      key: const ValueKey('save-profile-name'),
                      label: _saving
                          ? l10n.savingProfile
                          : widget.initialSetup
                          ? l10n.continueLabel
                          : l10n.saveProfile,
                      onPressed: _saving ? null : _save,
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          key: const ValueKey('profile-save-error'),
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
