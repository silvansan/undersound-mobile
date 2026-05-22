import 'package:flutter/material.dart';

import '../models/event_directory.dart';
import '../models/listener_link.dart';
import '../services/ablaut_api_client.dart';
import '../services/listener_access_messages.dart';
import '../services/listener_channel_launcher.dart';
import '../services/listener_session_coordinator.dart';
import '../widgets/listener_password_dialog.dart';

class EventChannelsScreen extends StatefulWidget {
  const EventChannelsScreen({
    super.key,
    required this.link,
    this.replaceCurrentRoute = false,
  });

  final ListenerLink link;
  final bool replaceCurrentRoute;

  @override
  State<EventChannelsScreen> createState() => _EventChannelsScreenState();
}

class _EventChannelsScreenState extends State<EventChannelsScreen> {
  final _api = const AblautApiClient();
  final _launcher = const ListenerChannelLauncher();

  EventDirectoryContext? _directory;
  String? _eventSessionToken;
  String? _error;
  bool _loading = true;
  bool _openingChannel = false;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final directory = await _api.loadEventDirectory(widget.link);
      if (!mounted) {
        return;
      }

      setState(() {
        _directory = directory;
        _loading = false;
      });

      if (directory.access.listenerPasswordRequired && _eventSessionToken == null) {
        await _promptForEventPassword(directory);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _promptForEventPassword(EventDirectoryContext directory) async {
    if (directory.access.listenerPasswordMissing) {
      setState(() {
        _error = ListenerAccessMessages.passwordMissing;
      });
      return;
    }

    var password = await showListenerPasswordDialog(context);
    while (mounted && password != null) {
      try {
        final response = await _api.verifyEventDirectoryPassword(
          link: widget.link,
          password: password,
        );
        setState(() {
          _eventSessionToken = response.listenerSessionToken;
          _error = null;
        });
        return;
      } on ApiException catch (error) {
        if (error.statusCode != 401 || !mounted) {
          setState(() => _error = error.message);
          return;
        }
        password = await showListenerPasswordDialog(
          context,
          errorText: ListenerAccessMessages.wrongPassword,
        );
      }
    }

    if (mounted) {
      setState(() {
        _error = 'Event listener password is required.';
      });
    }
  }

  Future<void> _openChannel(EventDirectoryChannel channel) async {
    if (_openingChannel) {
      return;
    }

    setState(() {
      _openingChannel = true;
      _error = null;
    });

    try {
      final channelLink = widget.link.withChannelSlug(channel.slug);
      await _launcher.openChannel(
        context: context,
        link: channelLink,
        eventListenerSessionToken: _eventSessionToken,
        replaceCurrentRoute: widget.replaceCurrentRoute,
      );
    } on ListenerAccessException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _openingChannel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = _directory;

    return Scaffold(
      appBar: AppBar(
        title: Text(directory?.eventTitle.isNotEmpty == true
            ? directory!.eventTitle
            : 'Choose channel'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choose a channel to listen.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (directory == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('This event directory is not available.'),
                  )
                else if (directory.access.listenerPasswordRequired &&
                    _eventSessionToken == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('Enter the event listener password to continue.'),
                  )
                else if (directory.channels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No listener channels are available right now.'),
                  )
                else ...[
                  const SizedBox(height: 16),
                  ...directory.channels.map(
                    (channel) => Card(
                      child: ListTile(
                        title: Text(channel.name),
                        subtitle: Text(
                          channel.languageLabel ??
                              channel.languageCode ??
                              'Listener channel',
                        ),
                        trailing: _openingChannel
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.headphones_rounded),
                        onTap: _openingChannel ? null : () => _openChannel(channel),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
