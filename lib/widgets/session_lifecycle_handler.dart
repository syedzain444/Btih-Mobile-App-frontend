import 'package:btih_andriod_app/services/analytics_session_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/content_service.dart';
import 'package:btih_andriod_app/services/health_service.dart';
import 'package:flutter/material.dart';

/// Session expiry, analytics start/end, and API health checks on lifecycle.
class SessionLifecycleHandler extends StatefulWidget {
  const SessionLifecycleHandler({super.key, required this.child});

  final Widget child;

  @override
  State<SessionLifecycleHandler> createState() =>
      _SessionLifecycleHandlerState();
}

class _SessionLifecycleHandlerState extends State<SessionLifecycleHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onForeground();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AnalyticsSessionService.instance.endIfActive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onForeground();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      AnalyticsSessionService.instance.endIfActive();
    }
  }

  Future<void> _onForeground() async {
    AuthSession.ensureValidSession();
    await HealthService.instance.check();
    if (AuthSession.isLoggedIn) {
      await AnalyticsSessionService.instance.startIfLoggedIn();
    }
    // Warm content cache for privacy / labels.
    // ignore: unawaited_futures
    ContentService.instance.load('en');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
