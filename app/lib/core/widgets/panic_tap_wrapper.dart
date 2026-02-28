import 'package:flutter/material.dart';

class PanicTapWrapper extends StatefulWidget {
  const PanicTapWrapper({
    required this.child,
    required this.onTripleTap,
    super.key,
  });

  final Widget child;
  final VoidCallback onTripleTap;

  @override
  State<PanicTapWrapper> createState() => _PanicTapWrapperState();
}

class _PanicTapWrapperState extends State<PanicTapWrapper> {
  DateTime? _firstTap;
  int _tapCount = 0;

  void _registerTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > const Duration(seconds: 2)) {
      _firstTap = now;
      _tapCount = 1;
      return;
    }

    _tapCount += 1;
    if (_tapCount >= 3) {
      _tapCount = 0;
      _firstTap = null;
      widget.onTripleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registerTap(),
      child: widget.child,
    );
  }
}
