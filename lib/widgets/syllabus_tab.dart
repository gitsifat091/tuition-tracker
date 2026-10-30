import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student.dart';
import '../models/syllabus_item.dart';
import '../providers/syllabus_provider.dart';
import '../theme/app_theme.dart';
import '../utils/bn.dart';
import 'common/ui_kit.dart';

class SyllabusTab extends StatelessWidget {
  final Student student;
  const SyllabusTab({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyllabusProvider>();
    final items = provider.forStudent(student.id);
    final progress = provider.progressFor(student.id);
    final doneCount = items.where((i) => i.isDone).length;

    // শেষ না হওয়াগুলো আগে — যেটা এখনো পড়ানো বাকি সেটাই আগে চোখে পড়া উচিত।
    final sorted = [...items]..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.createdAt.compareTo(b.createdAt);
      });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.checklist_outlined,
              title: 'এখনো কোনো টপিক যোগ করা হয়নি',
              message: 'যে অধ্যায়গুলো পড়াতে হবে সেগুলো লিখে রাখলে অগ্রগতি দেখা যাবে।',
              action: FilledButton.icon(
                onPressed: () => showSyllabusItemForm(context, student),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('প্রথম টপিক যোগ করো'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                100,
              ),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'সিলেবাস অগ্রগতি',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                          Text(
                            '${Bn.number(doneCount)} / ${Bn.number(items.length)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ThinProgressBar(value: progress, height: 8),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        progress >= 1
                            ? 'সব টপিক শেষ 🎉'
                            : '${Bn.number((progress * 100).round())}% সম্পন্ন, '
                                'বাকি ${Bn.number(items.length - doneCount)} টি',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final item in sorted) ...[
                  _SyllabusCard(item: item, student: student),
                  const SizedBox(height: AppSpacing.sm + 2),
                ],
              ],
            ),
      floatingActionButton: items.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => showSyllabusItemForm(context, student),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  final SyllabusItem item;
  final Student student;
  const _SyllabusCard({required this.item, required this.student});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => showSyllabusItemForm(context, student, existing: item),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      color: item.isDone ? AppColors.surfaceMuted : AppColors.surface,
      elevated: !item.isDone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // চেকবক্সে চাপ দিলে কার্ড না খুলে শুধু done টগল হবে।
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.read<SyllabusProvider>().toggleDone(item),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isDone ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: item.isDone ? AppColors.primary : AppColors.inkFaint,
                      width: 1.8,
                    ),
                  ),
                  child: item.isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.4,
                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.inkFaint,
                      color: item.isDone ? AppColors.inkFaint : AppColors.ink,
                    ),
                  ),
                ),
                if (item.materialNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.link, size: 13, color: AppColors.inkFaint),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.materialNote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkFaint,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showSyllabusItemForm(BuildContext context, Student student, {SyllabusItem? existing}) {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final materialCtrl = TextEditingController(text: existing?.materialNote ?? '');
  String? error;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xs,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'নতুন টপিক' : 'টপিক এডিট করুন',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: titleCtrl,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'টপিক / অধ্যায়ের নাম',
                  prefixIcon: Icon(Icons.topic_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: materialCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'স্টাডি ম্যাটেরিয়াল (ঐচ্ছিক)',
                  hintText: 'লিংক, বইয়ের নাম বা পৃষ্ঠা নম্বর',
                  prefixIcon: Icon(Icons.link),
                  alignLabelWithHint: true,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  if (existing != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await confirmDialog(
                            ctx,
                            title: 'টপিক ডিলিট করবে?',
                            message: '"${existing.title}" তালিকা থেকে মুছে যাবে।',
                            confirmLabel: 'ডিলিট',
                            destructive: true,
                          );
                          if (!ok || !ctx.mounted) return;
                          ctx.read<SyllabusProvider>().deleteItem(existing.id);
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('ডিলিট'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty) {
                          setSheetState(() => error = 'টপিকের নাম দাও');
                          return;
                        }
                        final provider = ctx.read<SyllabusProvider>();
                        if (existing == null) {
                          provider.addItem(
                            SyllabusItem(
                              studentId: student.id,
                              title: titleCtrl.text.trim(),
                              materialNote: materialCtrl.text.trim(),
                            ),
                          );
                        } else {
                          existing.title = titleCtrl.text.trim();
                          existing.materialNote = materialCtrl.text.trim();
                          provider.updateItem(existing);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('সেভ করুন'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    titleCtrl.dispose();
    materialCtrl.dispose();
  });
}
