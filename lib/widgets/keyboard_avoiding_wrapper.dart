import 'package:flutter/material.dart';

class KeyboardAvoidingWrapper extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final PreferredSizeWidget? appBar;

  const KeyboardAvoidingWrapper({
    Key? key,
    required this.child,
    required this.backgroundColor,
    this.appBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         (appBar != null ? kToolbarHeight : 0) -
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 48,
            ),
            child: IntrinsicHeight(
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}