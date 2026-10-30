import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/bn.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum _Role { teacher, student }

class _SignupScreenState extends State<SignupScreen> {
  _Role _role = _Role.teacher;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    // বাংলা কিবোর্ডে কোড লিখলেও যেন মেলে।
    final code = Bn.toAsciiDigits(_codeCtrl.text.trim());

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'সব ঘর পূরণ করো');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'পাসওয়ার্ড অন্তত ৬ ক্যারেক্টার হতে হবে');
      return;
    }
    if (_role == _Role.student && code.isEmpty) {
      setState(() => _error = 'ইনভাইট কোড দাও');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final error = _role == _Role.teacher
        ? await auth.signUpTeacher(name: name, email: email, password: password)
        : await auth.signUpStudent(
            name: name,
            email: email,
            password: password,
            inviteCode: code,
          );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });

    if (error == null) {
      // সফল হলে SignupScreen বন্ধ — নিচে AuthGate ততক্ষণে আপডেটেড role দেখে
      // সঠিক home screen এ পাঠাবে।
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == _Role.student;

    return Scaffold(
      appBar: AppBar(title: const Text('নতুন অ্যাকাউন্ট')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.sm,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'আমি কে?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          label: 'শিক্ষক',
                          caption: 'ছাত্র ও ফি সামলাবো',
                          icon: Icons.person_outline,
                          selected: !isStudent,
                          onTap: () => setState(() => _role = _Role.teacher),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _RoleCard(
                          label: 'ছাত্র/ছাত্রী',
                          caption: 'নিজের অগ্রগতি দেখবো',
                          icon: Icons.backpack_outlined,
                          selected: isStudent,
                          onTap: () => setState(() => _role = _Role.student),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'নাম',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'ইমেইল',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: isStudent ? TextInputAction.next : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'পাসওয়ার্ড',
                      helperText: 'অন্তত ৬ ক্যারেক্টার',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  if (isStudent) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'ইনভাইট কোড',
                        helperText: 'টিউটরের কাছ থেকে পাওয়া ৬ অঙ্কের কোড',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _signUp,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('অ্যাকাউন্ট তৈরি করো'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final String caption;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.inkFaint, size: 25),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13.5,
                  color: selected ? AppColors.primary : AppColors.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
