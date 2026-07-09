import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/models/team_member.dart';
import '../../../providers/auth_provider.dart';
import '../../team/providers/team_providers.dart';
import '../providers/approvals_providers.dart';

/// Opens the request-approval dialog for a subject. Returns true when a request
/// was created.
Future<bool?> showRequestApprovalDialog(
  BuildContext context, {
  required String subjectType,
  required int subjectId,
  required String subjectTitle,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _RequestApprovalDialog(
      subjectType: subjectType,
      subjectId: subjectId,
      subjectTitle: subjectTitle,
    ),
  );
}

class _RequestApprovalDialog extends ConsumerStatefulWidget {
  const _RequestApprovalDialog({
    required this.subjectType,
    required this.subjectId,
    required this.subjectTitle,
  });
  final String subjectType;
  final int subjectId;
  final String subjectTitle;

  @override
  ConsumerState<_RequestApprovalDialog> createState() =>
      _RequestApprovalDialogState();
}

class _RequestApprovalDialogState
    extends ConsumerState<_RequestApprovalDialog> {
  int? _approverId;
  final TextEditingController _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_approverId == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(approvalsRepositoryProvider)
          .request(
            subjectType: widget.subjectType,
            subjectId: widget.subjectId,
            subjectTitle: widget.subjectTitle,
            approverId: _approverId!,
            note: _note.text.trim(),
          );
      ref.invalidate(myApprovalRequestsProvider);
      ref.invalidate(
        approvalsForSubjectProvider((
          type: widget.subjectType,
          id: widget.subjectId,
        )),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not request: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int myId =
        ref.watch(authControllerProvider).asData?.value.user?.id ?? 0;
    final List<TeamMember> members =
        (ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[])
            .where((TeamMember m) => m.id != myId)
            .toList();
    return AlertDialog(
      title: const Text('Request approval'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.subjectTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _approverId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Approver'),
              items: <DropdownMenuItem<int>>[
                for (final TeamMember m in members)
                  DropdownMenuItem<int>(
                    value: m.id,
                    child: Text(
                      m.name.isEmpty ? m.email : m.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (int? v) => setState(() => _approverId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _approverId == null || _busy ? null : _save,
          child: const Text('Request'),
        ),
      ],
    );
  }
}

/// A small pending/approved/rejected chip shared by the approvals UI.
class ApprovalStatusChip extends StatelessWidget {
  const ApprovalStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      'approved' => (const Color(0xFF16A34A), 'Approved'),
      'rejected' => (const Color(0xFFE11D48), 'Rejected'),
      _ => (const Color(0xFFF59E0B), 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
