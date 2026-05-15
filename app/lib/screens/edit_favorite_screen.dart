import 'package:flutter/material.dart';

import '../models/favorite_channel.dart';
import '../services/listener_link_parser.dart';

class EditFavoriteScreen extends StatefulWidget {
  const EditFavoriteScreen({super.key, this.favorite});

  final FavoriteChannel? favorite;

  @override
  State<EditFavoriteScreen> createState() => _EditFavoriteScreenState();
}

class _EditFavoriteScreenState extends State<EditFavoriteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.favorite?.name ?? '');
    _urlController = TextEditingController(text: widget.favorite?.url ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final now = DateTime.now();
    final favorite = widget.favorite == null
        ? FavoriteChannel(
            id: now.microsecondsSinceEpoch.toString(),
            name: _nameController.text.trim(),
            url: _urlController.text.trim(),
            createdAt: now,
            updatedAt: now,
          )
        : widget.favorite!.copyWith(
            name: _nameController.text.trim(),
            url: _urlController.text.trim(),
            updatedAt: now,
          );
    Navigator.of(context).pop(favorite);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.favorite != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit favorite' : 'Add favorite')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Name',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter a name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              minLines: 3,
              maxLines: 5,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Listener URL',
                hintText: 'https://your-server/e/event/EN/listen?token=...',
              ),
              validator: (value) {
                try {
                  ListenerLinkParser.parse(value ?? '');
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(editing ? 'Save changes' : 'Add favorite'),
            ),
          ],
        ),
      ),
    );
  }
}
