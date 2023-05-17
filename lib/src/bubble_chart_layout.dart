import 'dart:math';

import 'package:bubble_chart/bubble_chart.dart';
import 'package:bubble_chart/src/bubble_layer.dart';
import 'package:flutter/material.dart';

class BubbleChartLayout extends StatelessWidget {
  final List<BubbleNode> children;
  final double Function(BubbleNode)? radius;
  final Duration? duration;
  // Stretch factor determines the width:height ratio of the chart
  final double stretchFactor;

  BubbleChartLayout({
    required this.children,
    this.radius,
    this.duration,
    this.stretchFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var bubbles = BubbleChart(
          root: BubbleNode.node(children: children),
          radius: radius,
          size: Size(constraints.maxWidth, constraints.maxHeight),
          stretchFactor: stretchFactor,
        );

        // These are the maximum values used by the bubbles
        double maxXUsed = 0.0, maxYUsed = 0.0;
        for (final node in bubbles.nodes) {
          maxXUsed = max(maxXUsed, (node.x! + node.radius!));
          maxYUsed = max(maxYUsed, (node.y! + node.radius!));
        }

        return ScaleView(
          bubblesMaxX: maxXUsed,
          bubblesMaxY: maxYUsed,
          parentWidth: constraints.maxWidth,
          parentHeight: constraints.maxHeight,
          child: Stack(
            children: bubbles.nodes.fold([], (result, node) {
              return result
                ..add(
                  duration == null
                      ? Positioned(
                          key: node.key,
                          top: node.y! - node.radius!,
                          left: node.x! - node.radius!,
                          width: node.radius! * 2,
                          height: node.radius! * 2,
                          child: BubbleLayer(bubble: node),
                        )
                      : AnimatedPositioned(
                          key: node.key,
                          top: node.y! - node.radius!,
                          left: node.x! - node.radius!,
                          width: node.radius! * 2,
                          height: node.radius! * 2,
                          duration: duration ?? Duration(milliseconds: 300),
                          child: BubbleLayer(bubble: node),
                        ),
                );
            }),
          ),
        );
      },
    );
  }
}

// An interactive viewer that will automatically zoom in on the child so it fits the parent closely
class ScaleView extends StatefulWidget {
  final Widget child;
  final double bubblesMaxX;
  final double bubblesMaxY;
  final double parentWidth;
  final double parentHeight;

  const ScaleView({
    Key? key,
    required this.child,
    required this.bubblesMaxX,
    required this.bubblesMaxY,
    required this.parentWidth,
    required this.parentHeight,
  }) : super(key: key);

  @override
  _ScaleViewState createState() => _ScaleViewState();
}

class _ScaleViewState extends State<ScaleView> {
  TransformationController _controller = TransformationController();
  double autoScale = 1.0;

  double _getCurrentScale(TransformationController controller) {
    final matrix = controller.value;
    return matrix.getMaxScaleOnAxis();
  }

  // Return if the current scale has been adjusted from the default
  bool _hasUserChangedScale() {
    final currentScale = _getCurrentScale(_controller);
    return (currentScale - autoScale).abs() > 0.05;
  }

  void setScale() {
    final bubbleXPadding = widget.parentWidth - widget.bubblesMaxX;
    final bubbleYPadding = widget.parentHeight - widget.bubblesMaxY;
    // bubbles max values include the inner padding so we need to remove it to get the bubbles sizes
    final bubblesWidth = widget.bubblesMaxX - bubbleXPadding;
    final bubblesHeight = widget.bubblesMaxY - bubbleYPadding;
    autoScale = min(
      widget.parentWidth / bubblesWidth,
      widget.parentHeight / bubblesHeight,
    );

    // Calculate the translation needed to center the child
    final originalCenterX = widget.parentWidth / 2;
    final scaledBubbleWidth = bubblesWidth * autoScale;
    final scaledPadding = bubbleXPadding * autoScale;
    final newPaddingForCenter = (originalCenterX - (scaledBubbleWidth / 2));
    // Set the dx to the difference in the scaledPadding and the required padding for centering the scaled bubbles
    // We only need to apply half of this because the bubbles are already centered in their parents
    final dx = (scaledPadding - newPaddingForCenter) / 2;

    // Move the bubbles to the top of the child
    final dy = bubbleYPadding;

    _controller.value = Matrix4.identity()
      ..scale(autoScale)
      ..translate(-dx, -dy);
  }

  @override
  void initState() {
    super.initState();
    _controller.value = Matrix4.identity()..scale(autoScale);
    setScale();
  }

  // If childMax values change than we need to re-calculate the scale
  @override
  void didUpdateWidget(covariant ScaleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bubblesMaxX != widget.bubblesMaxX ||
        oldWidget.bubblesMaxY != widget.bubblesMaxY) {
      if (!_hasUserChangedScale()) setScale();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      child: widget.child,
    );
  }
}
