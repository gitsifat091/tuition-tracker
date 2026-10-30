import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_features.dart';
import '../models/student.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import '../utils/time_format.dart';
import '../widgets/common/ui_kit.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? existing;
  const AddStudentScreen({super.key, this.existing});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _classCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _feeCtrl;
  late List<String> _selectedDays;
  TimeOfDay? _selectedTime;
  late DateTime _joinDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _classCtrl = TextEditingController(text: s?.className ?? '');
    _subjectCtrl = TextEditingController(text: s?.subject ?? '');
    _phoneCtrl = TextEditingController(text: s?.parentPhone ?? '');
    _feeCtrl = TextEditingController(text: s?.monthlyFee.toStringAsFixed(0) ?? '');
    _selectedDays = List<String>.from(s?.classDays ?? []);
    _selectedTime = parseTimeOfDay(s?.classTime);
    _joinDate = s?.joinDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classCtrl.dispose();
    _subjectCtrl.dispose();
    _phoneCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  /// আগে এখানে `provider.addStudent(...)` await ছাড়াই ডাকা হতো আর সাথে সাথেই
  /// `Navigator.pop()` — তাই ইন্টারনেট না থাকলে বা Firestore rule আটকালে
  /// ব্যবহারকারী কিছুই জানত না, শুধু স্ক্রিন বন্ধ হয়ে যেত।
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<StudentProvider>();
    final phone = _phoneCtrl.text.trim();

    // ফি লুকানো থাকলেও কন্ট্রোলারটা initState এ পুরনো মান নিয়েই তৈরি হয়, তাই
    // এডিট করলে আগের মাসিক ফি অক্ষত থাকে। নতুন ছাত্রের ক্ষেত্রে ঘরটা খালি
    // থাকায় ০ বসবে — ফি আবার চালু করলে তখন বসিয়ে নিতে হবে।
    final monthlyFee = double.tryParse(_feeCtrl.text.trim()) ?? 0;

    try {
      if (_isEditing) {
        await provider.updateStudent(
          widget.existing!.copyWith(
            name: _nameCtrl.text.trim(),
            className: _classCtrl.text.trim(),
            subject: _subjectCtrl.text.trim(),
            parentPhone: phone.isEmpty ? null : phone,
            monthlyFee: monthlyFee,
            classDays: _selectedDays,
            classTime: formatTimeOfDay(_selectedTime),
            joinDate: _joinDate,
          ),
        );
      } else {
        await provider.addStudent(
          Student(
            name: _nameCtrl.text.trim(),
            className: _classCtrl.text.trim(),
            subject: _subjectCtrl.text.trim(),
            parentPhone: phone.isEmpty ? null : phone,
            monthlyFee: monthlyFee,
            classDays: _selectedDays,
            classTime: formatTimeOfDay(_selectedTime),
            joinDate: _joinDate,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'সেভ করা যায়নি: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'তথ্য এডিট করুন' : 'নতুন ছাত্র যোগ করুন'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 40),
          children: [
            const SectionTitle(title: 'মূল তথ্য'),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'নাম',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'নাম দিন' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _classCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ক্লাস',
                            prefixIcon: Icon(Icons.class_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'ক্লাস দিন' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _subjectCtrl,
                          decoration: const InputDecoration(
                            labelText: 'বিষয়',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'বিষয় দিন' : null,
                        ),
                      ),
                    ],
                  ),
                  if (AppFeatures.feesEnabled) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _feeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'মাসিক ফি (৳)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final value = double.tryParse((v ?? '').trim());
                        if (value == null) return 'সঠিক পরিমাণ দিন';
                        if (value < 0) return 'ঋণাত্মক হতে পারে না';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'অভিভাবকের নম্বর (ঐচ্ছিক)',
                      helperText: 'ফি রিমাইন্ডার আর ইনভাইট কোড এই নম্বরে যাবে',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const SectionTitle(title: 'ক্লাসের রুটিন'),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'কোন কোন দিন ক্লাস',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: Bn.weekDaysShort.map((day) {
                      final selected = _selectedDays.contains(day);
                      return _DayToggle(
                        label: day,
                        selected: selected,
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  InfoRow(
                    icon: Icons.access_time,
                    label: 'ক্লাসের সময়',
                    value: _selectedTime != null ? formatTimeOfDay(_selectedTime)! : 'দেওয়া হয়নি',
                    valueColor: _selectedTime == null ? AppColors.inkFaint : null,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (picked != null) setState(() => _selectedTime = picked);
                    },
                  ),
                  const Divider(),
                  InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'পড়ানো শুরু',
                    value: Bn.date(_joinDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _joinDate,
                        firstDate: DateTime(2015, 1, 1),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _joinDate = picked);
                    },
                  ),
                  if (_selectedTime != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _selectedTime = null),
                        icon: const Icon(Icons.close, size: 15),
                        label: const Text('সময় মুছো'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.inkFaint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'আপডেট করুন' : 'সেভ করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.primary : AppColors.borderStrong),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.inkMuted,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
