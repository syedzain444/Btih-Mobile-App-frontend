import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:flutter/material.dart';

/// Checks session expiry when the app resumes or returns to foreground.
class SessionLifecycleHandler extends StatefulWidget {
  const SessionLifecycleHandler({super.key, required this.child});

  final Widget child;

  @override
  State<SessionLifecycleHandler> createState() => _SessionLifecycleHandlerState();
}

class _SessionLifecycleHandlerState extends State<SessionLifecycleHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuthSession.ensureValidSession();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
