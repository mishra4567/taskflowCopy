import 'package:flutter/material.dart';

/// Central place to show a themed SnackBar. Clears any SnackBar already
/// on screen first so rapid taps (e.g. menu actions) don't queue up a
/// backlog of messages.
void showAppSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
