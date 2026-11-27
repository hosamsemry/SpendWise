import 'package:flutter/material.dart';

/// Shared layout for Settings and its sub-pages: app bar + padded,
/// scrollable list that clears the system navigation bar.
class SettingsPageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: children,
        ),
      ),
    );
  }
}
