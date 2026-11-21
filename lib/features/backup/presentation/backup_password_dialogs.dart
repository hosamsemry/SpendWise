import 'package:flutter/material.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/backup/data/backup_crypto.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';

/// What the user chose in [showExportBackupDialog].
class BackupExportChoice {
  /// Encryption password, or `null` for a plain (readable) backup.
  final String? password;
  const BackupExportChoice(this.password);
}

/// Asks whether to password-protect an export (on by default).
/// Returns `null` if the user cancelled.
Future<BackupExportChoice?> showExportBackupDialog(BuildContext context) {
  return showDialog<BackupExportChoice>(
    context: context,
    builder: (_) => const _ExportBackupDialog(),
  );
}

class _ExportBackupDialog extends StatefulWidget {
  const _ExportBackupDialog();

  @override
  State<_ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<_ExportBackupDialog> {
  bool _protect = true;
  bool _obscure = true;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_protect) {
      Navigator.pop(context, const BackupExportChoice(null));
      return;
    }
    final l10n = context.l10n;
    if (_password.text.length < BackupCrypto.minPasswordLength) {
      setState(() => _error =
          l10n.backupPasswordTooShort(BackupCrypto.minPasswordLength));
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = l10n.backupPasswordsDoNotMatch);
      return;
    }
    Navigator.pop(context, BackupExportChoice(_password.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.createBackup),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              key: const ValueKey('protect_backup_switch'),
              contentPadding: EdgeInsets.zero,
              value: _protect,
              activeTrackColor: context.primaryColor,
              title: Text(l10n.protectBackupTitle),
              subtitle: Text(
                l10n.protectBackupSubtitle,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              onChanged: (v) => setState(() {
                _protect = v;
                _error = null;
              }),
            ),
            if (_protect) ...[
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('backup_password_field'),
                controller: _password,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.backupPasswordLabel,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('backup_password_confirm_field'),
                controller: _confirm,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.backupPasswordConfirmLabel,
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.backupPasswordForgetWarning,
                style: TextStyle(fontSize: 12, color: context.warningColor),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.backupUnprotectedWarning,
                  style: TextStyle(fontSize: 12, color: context.warningColor),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          key: const ValueKey('export_backup_confirm'),
          onPressed: _submit,
          child: Text(l10n.exportBackupAction),
        ),
      ],
    );
  }
}

/// Prompts for the password of an encrypted backup and runs [unlock] with
/// it, keeping the dialog open (with an error) on a wrong password.
/// Returns the decrypted backup, or `null` if the user cancelled.
Future<BackupData?> showUnlockBackupDialog(
  BuildContext context, {
  required Future<BackupData> Function(String password) unlock,
}) {
  return showDialog<BackupData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnlockBackupDialog(unlock: unlock),
  );
}

class _UnlockBackupDialog extends StatefulWidget {
  final Future<BackupData> Function(String password) unlock;
  const _UnlockBackupDialog({required this.unlock});

  @override
  State<_UnlockBackupDialog> createState() => _UnlockBackupDialogState();
}

class _UnlockBackupDialogState extends State<_UnlockBackupDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.unlock(_password.text);
      if (mounted) Navigator.pop(context, data);
    } on WrongBackupPasswordException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.wrongBackupPassword;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.encryptedBackupTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.encryptedBackupBody,
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('unlock_backup_password_field'),
            controller: _password,
            obscureText: _obscure,
            enabled: !_busy,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.backupPasswordLabel,
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          key: const ValueKey('unlock_backup_confirm'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.unlockBackupAction),
        ),
      ],
    );
  }
}
