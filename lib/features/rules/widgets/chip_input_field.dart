import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_spacing.dart';

/// Free-text chip input: type a value, press add (or submit) to turn it
/// into a removable chip. Used for brands, senders and keywords.
class ChipInputField extends StatefulWidget {
  const ChipInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.helper,
    this.capitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String? helper;
  final TextCapitalization capitalization;

  @override
  State<ChipInputField> createState() => _ChipInputFieldState();
}

class _ChipInputFieldState extends State<ChipInputField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final exists =
        widget.values.any((v) => v.toLowerCase() == value.toLowerCase());
    if (!exists) widget.onChanged([...widget.values, value]);
    _controller.clear();
  }

  void _remove(String value) {
    widget.onChanged(widget.values.where((v) => v != value).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        if (widget.values.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final value in widget.values)
                InputChip(
                  label: Text(value),
                  onDeleted: () => _remove(value),
                  deleteButtonTooltipMessage: 'Remove',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: _controller,
          textCapitalization: widget.capitalization,
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            suffixIcon: IconButton(
              tooltip: 'Add',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _add(_controller.text),
            ),
          ),
        ),
      ],
    );
  }
}
