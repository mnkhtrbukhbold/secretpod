import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import 'common.dart';
import 'dropdown_field.dart';
import 'dialog_shell.dart';

class ActionDialog extends StatefulWidget {
  const ActionDialog({
    super.key,
    required this.title,
    required this.label,
    required this.description,
    required this.submitLabel,
    required this.onSubmit,
    this.member = false,
    this.initialValue = '',
  });
  final String title, label, description, submitLabel;
  final Future<void> Function(String value, String role) onSubmit;
  final bool member;
  final String initialValue;
  @override
  State<ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<ActionDialog> {
  late final _text = TextEditingController(text: widget.initialValue);
  final _form = GlobalKey<FormState>();
  String _role = 'reader';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !validateDialogForm(_form.currentState!)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_text.text, _role);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = VaultController.describeError(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  style: TextStyle(color: context.colors.muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _text,
                  enabled: !_busy,
                  autofocus: true,
                  maxLength: widget.member ? 254 : 80,
                  keyboardType: widget.member
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  decoration: InputDecoration(labelText: widget.label),
                  validator: (s) {
                    if (s!.trim().isEmpty) return 'This field is required.';
                    if (s.trim().length > (widget.member ? 254 : 80)) {
                      return 'Use at most ${widget.member ? 254 : 80} characters.';
                    }
                    return null;
                  },
                  onFieldSubmitted: _busy ? null : (_) => _submit(),
                ),
                if (widget.member) ...[
                  const SizedBox(height: 12),
                  SecretPodDropdown<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Access level',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'reader',
                        child: Text('Reader · view and reveal'),
                      ),
                      DropdownMenuItem(
                        value: 'editor',
                        child: Text('Editor · create and manage'),
                      ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _role = v!),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  DialogErrorNotice(_error!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : widget.submitLabel),
        ),
      ],
    ),
  );
}
