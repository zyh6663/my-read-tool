import 'package:flutter/material.dart';

import '../services/source_service.dart';

class SourceCard extends StatelessWidget {
  final BookSource source;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTest;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SourceCard({super.key, required this.source, this.onToggle, this.onTest, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final locked = source.isBuiltin;
    return Card(
      child: ListTile(
        title: Text(source.name),
        subtitle: Text(source.baseUrl),
        trailing: Wrap(
          spacing: 4,
          children: [
            Switch(value: source.enabled, onChanged: onToggle),
            IconButton(onPressed: onTest, icon: const Icon(Icons.science_outlined)),
            IconButton(onPressed: locked ? null : onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: locked ? null : onDelete, icon: const Icon(Icons.delete_outline)),
          ],
        ),
      ),
    );
  }
}
