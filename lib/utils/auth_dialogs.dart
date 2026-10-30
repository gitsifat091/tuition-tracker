import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/ui_kit.dart';

Future<void> confirmAndSignOut(BuildContext context) async {
  final confirm = await confirmDialog(
    context,
    title: 'লগআউট করবে?',
    message: 'আবার লগইন করতে হবে।',
    confirmLabel: 'লগআউট',
    destructive: true,
  );
  if (confirm && context.mounted) {
    await context.read<AuthProvider>().signOut();
  }
}
