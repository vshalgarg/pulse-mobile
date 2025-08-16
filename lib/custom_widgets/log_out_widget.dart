import 'package:flutter/material.dart';

class LogoutWidget extends StatefulWidget {
  const LogoutWidget({super.key});

  @override
  State<LogoutWidget> createState() => _LogoutWidgetState();
}

class _LogoutWidgetState extends State<LogoutWidget> {
  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text('Do you want to exit this application?'),
      content: Text('We hate to see you leave...'),
      actions: <Widget>[
        InkWell(
          child: Text('No'),
        ),
        InkWell(
          child: Text('Yes'),
        ),
      ],
    );
  }
}
