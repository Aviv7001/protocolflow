import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UnsavedChangesPopScope extends StatefulWidget {
  final bool canPop;
  final Widget child;
  final String message;

  const UnsavedChangesPopScope({
    super.key,
    required this.canPop,
    required this.child,
    this.message = 'You have unsaved changes. Are you sure you want to exit?',
  });

  @override
  State<UnsavedChangesPopScope> createState() => _UnsavedChangesPopScopeState();
}

class _UnsavedChangesPopScopeState extends State<UnsavedChangesPopScope> {
  bool _allowPop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canPop || _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: Text(widget.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        if (shouldPop == true && context.mounted) {
          setState(() => _allowPop = true);
          Navigator.pop(context);
        }
      },
      child: widget.child,
    );
  }
}
