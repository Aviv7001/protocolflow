import 'package:flutter/material.dart';

enum ProtocolFlowWindowClass { mobile, tablet, desktop }

abstract final class ProtocolFlowBreakpoints {
  static const double tablet = 600;
  static const double desktop = 900;
}

extension ProtocolFlowResponsive on BuildContext {
  ProtocolFlowWindowClass get windowClass {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= ProtocolFlowBreakpoints.desktop) {
      return ProtocolFlowWindowClass.desktop;
    }
    if (width >= ProtocolFlowBreakpoints.tablet) {
      return ProtocolFlowWindowClass.tablet;
    }
    return ProtocolFlowWindowClass.mobile;
  }

  bool get isMobileLayout => windowClass == ProtocolFlowWindowClass.mobile;

  bool get isTabletLayout => windowClass == ProtocolFlowWindowClass.tablet;

  bool get isDesktopLayout => windowClass == ProtocolFlowWindowClass.desktop;
}

class ResponsiveLayoutBuilder extends StatelessWidget {
  const ResponsiveLayoutBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ProtocolFlowBreakpoints.desktop) {
          return (desktop ?? tablet ?? mobile)(context);
        }
        if (constraints.maxWidth >= ProtocolFlowBreakpoints.tablet) {
          return (tablet ?? mobile)(context);
        }
        return mobile(context);
      },
    );
  }
}
