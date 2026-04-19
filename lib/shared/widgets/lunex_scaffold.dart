import 'package:flutter/material.dart';

class LunexScaffold extends StatelessWidget {
  const LunexScaffold({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}
