import 'package:flutter/material.dart';

/// Rounded search input used on Home, Learn, and Community. Distinct
/// from [AppTextField] because search fields never show a label/error
/// and always carry a leading search icon plus optional filter action.
class SearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;

  const SearchField({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: onFilterTap != null
            ? IconButton(
                tooltip: 'Filter',
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: onFilterTap,
              )
            : null,
      ),
    );
  }
}
