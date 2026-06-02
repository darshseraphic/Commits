// lib/features/settings/widgets/export_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../shared/widgets/bento_card.dart';

void showExportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ExportSheet(),
  );
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  bool _exporting = false;
  String? _error;

  ExportService get _service => ExportService(
        db: ref.read(databaseProvider),
        diaryRepository: ref.read(diaryRepositoryProvider),
      );

  Future<void> _doEncrypted() async {
    setState(() { _exporting = true; _error = null; });
    try {
      await _service.exportEncrypted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Export failed. Please try again.'; });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmPlaintext() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AsrioColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Plaintext export', style: AsrioText.cardTitle),
        content: Text(
          'Your diary entries will be decrypted in this file.\n\n'
          'Anyone with this file can read your diary. '
          'Store it securely or share only with trusted people.',
          style: AsrioText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AsrioText.taskTitle
                    .copyWith(color: AsrioColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Export anyway',
                style: AsrioText.taskTitle
                    .copyWith(color: AsrioColors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _exporting = true; _error = null; });
    try {
      await _service.exportPlaintext();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Export failed. Please try again.'; });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AsrioColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: AsrioColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Export Your Data', style: AsrioText.cardTitle),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to export your ASRIO data.',
            style: AsrioText.bodyMuted,
          ),
          const SizedBox(height: 24),

          // Encrypted option
          GestureDetector(
            onTap: _exporting ? null : () {
              HapticFeedback.lightImpact();
              _doEncrypted();
            },
            child: BentoCard.white(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                        color: AsrioColors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_rounded,
                        color: AsrioColors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Encrypted Export',
                            style: AsrioText.taskTitle.copyWith(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('.enc · AES-256 secured · Device only',
                            style: AsrioText.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AsrioColors.muted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Plaintext option
          GestureDetector(
            onTap: _exporting ? null : () {
              HapticFeedback.lightImpact();
              _confirmPlaintext();
            },
            child: BentoCard.white(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AsrioColors.offWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AsrioColors.border, width: 0.8),
                    ),
                    child: const Icon(Icons.description_outlined,
                        color: AsrioColors.black, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plaintext Export',
                            style: AsrioText.taskTitle.copyWith(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 11,
                                color: AsrioColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                                '.json · Human readable · Store securely',
                                style: AsrioText.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AsrioColors.muted),
                ],
              ),
            ),
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: AsrioText.bodyMuted
                .copyWith(color: AsrioColors.dangerBorder)),
          ],

          // Loading overlay
          if (_exporting) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(
                  color: AsrioColors.black, strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}
