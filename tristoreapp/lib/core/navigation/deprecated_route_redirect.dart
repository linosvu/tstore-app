import 'package:flutter/material.dart';

/// Replaces legacy named routes with a clear redirect to [targetRoute].
class DeprecatedRouteRedirect extends StatefulWidget {
  const DeprecatedRouteRedirect({
    super.key,
    required this.targetRoute,
  });

  final String targetRoute;

  @override
  State<DeprecatedRouteRedirect> createState() => _DeprecatedRouteRedirectState();
}

class _DeprecatedRouteRedirectState extends State<DeprecatedRouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(widget.targetRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
