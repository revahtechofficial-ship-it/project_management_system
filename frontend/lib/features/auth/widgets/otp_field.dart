import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single, large, centred 6-digit code input.
class OtpField extends StatelessWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 12,
      ),
      decoration: const InputDecoration(
        counterText: '',
        hintText: '••••••',
        border: OutlineInputBorder(),
      ),
      validator: (String? v) =>
          (v == null || v.length != 6) ? 'Enter the 6-digit code' : null,
    );
  }
}
