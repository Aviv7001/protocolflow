import 'package:flutter/material.dart';

class HorizontalTableScroll extends StatefulWidget {
  const HorizontalTableScroll({
    super.key,
    required this.child,
    this.minWidth = 520,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final double minWidth;
  final EdgeInsetsGeometry padding;

  @override
  State<HorizontalTableScroll> createState() => _HorizontalTableScrollState();
}

class _HorizontalTableScrollState extends State<HorizontalTableScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.minWidth;
        final tableWidth = viewportWidth > widget.minWidth
            ? viewportWidth
            : widget.minWidth;

        return Scrollbar(
          controller: _controller,
          thumbVisibility: tableWidth > viewportWidth,
          trackVisibility: tableWidth > viewportWidth,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
