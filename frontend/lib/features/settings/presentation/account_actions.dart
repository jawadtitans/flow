import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/flow_dialog.dart';
import '../../auth/auth_controller.dart';
import '../../auth/presentation/auth_components.dart';

Future<bool> _confirm(
  BuildContext context,
  String title,
  Widget content,
  String action,
) async =>
    await showFlowDialog<bool>(
      context: context,
      builder: (context) => FlowDialog(
        title: title,
        content: content,
        actions: [
          FlowDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          FlowDialogAction(
            label: action,
            primary: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> confirmLogout(BuildContext context) => _confirm(
  context,
  'Log out of Flow?',
  const Text(
    'You can sign in again with your email and password or an email code.',
  ),
  'Log out',
);

Future<void> confirmAccountDeletion(BuildContext context, WidgetRef ref) async {
  if (ref.read(authControllerProvider).busy) return;
  if (!await _confirm(
    context,
    'Delete your account?',
    const Text(
      'Your profile, tasks, routines, reminders and notifications will be permanently deleted. This cannot be undone.',
    ),
    'Delete',
  )) {
    return;
  }
  if (!context.mounted) return;
  final typed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _DeleteConfirmationSheet(),
  );
  if (typed != true || !context.mounted) return;
  final accepted = await _confirm(
    context,
    'Confirm permanent deletion',
    const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your account and its data cannot be recovered after deletion.'),
        SizedBox(height: 16),
        Text(
          'مسئولیت بعدی به عهدهٔ خودتان است.',
          textDirection: TextDirection.rtl,
        ),
      ],
    ),
    'Delete permanently',
  );
  if (!accepted || !context.mounted) return;
  final success = await ref
      .read(authControllerProvider.notifier)
      .deleteAccount();
  if (!context.mounted) return;
  if (success) {
    context.go('/auth');
    showAuthMessage(context, 'Your account has been deleted.');
  } else {
    showAuthMessage(
      context,
      ref.read(authControllerProvider).error ??
          'Could not delete your account. Try again.',
    );
  }
}

class _DeleteConfirmationSheet extends StatefulWidget {
  const _DeleteConfirmationSheet();
  @override
  State<_DeleteConfirmationSheet> createState() =>
      _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState extends State<_DeleteConfirmationSheet> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      28,
      24,
      MediaQuery.viewInsetsOf(context).bottom +
          MediaQuery.paddingOf(context).bottom +
          24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirm account deletion',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const Text('Type Delete to continue.'),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('delete-account-confirmation'),
          controller: _text,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Delete'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBA1A1A),
          ),
          onPressed: _text.text == 'Delete'
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Continue deletion'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep my account'),
        ),
      ],
    ),
  );
}

class AccountPhotoEditor extends ConsumerStatefulWidget {
  const AccountPhotoEditor({super.key});
  @override
  ConsumerState<AccountPhotoEditor> createState() => _AccountPhotoEditorState();
}

class _AccountPhotoEditorState extends ConsumerState<AccountPhotoEditor> {
  bool _picking = false;

  Future<void> _pick() async {
    if (_picking || ref.read(authControllerProvider).busy) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 512000) {
        showAuthMessage(context, 'Choose a photo smaller than 500 KB.');
        return;
      }
      await _save(base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        showAuthMessage(
          context,
          'Could not open this photo. Check photo access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save(String? photo) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .updatePhoto(photo);
    if (!mounted) return;
    showAuthMessage(
      context,
      success
          ? 'Profile photo updated.'
          : ref.read(authControllerProvider).error ?? 'Could not update photo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final photo = auth.user?.profilePhoto;
    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: ClipOval(
                child: photo == null
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(LucideIcons.user_round, size: 46),
                      )
                    : Image.memory(
                        base64Decode(photo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(LucideIcons.user_round, size: 46),
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'Change profile photo',
                onPressed: auth.busy || _picking ? null : _pick,
                icon: const Icon(LucideIcons.camera, size: 20),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: auth.busy || _picking ? null : _pick,
          child: Text(
            _picking || auth.busy ? 'Please wait...' : 'Change photo',
          ),
        ),
        if (photo != null)
          TextButton(
            onPressed: auth.busy || _picking ? null : () => _save(null),
            child: const Text('Remove photo'),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
