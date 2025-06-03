import 'package:flutter/material.dart';

class GutterStyle{
  final TextStyle? lineNumberStyle;
  final Color breakpointColor, unfilledBreakpointColor;
  final Color? dividerColor;
  final double? breakpointSize, gutterWidth;
  final double gutterRightMargin, gutterLeftMargin;
  final IconData breakpointIcon, unfilledBreakpointIcon;
  final LineNumberAlignment lineNumberAlignment;
  GutterStyle({
    this.lineNumberStyle,
    this.dividerColor,
    this.gutterWidth,
    this.gutterRightMargin = 10,
    this.gutterLeftMargin = 10,
    this.lineNumberAlignment = LineNumberAlignment.center,
    this.breakpointIcon = Icons.circle,
    this.unfilledBreakpointIcon = Icons.circle_outlined,
    this.breakpointSize,
    this.breakpointColor = Colors.red,
    this.unfilledBreakpointColor = Colors.transparent
  });
}

enum LineNumberAlignment {
  center,
  left,
  right,
}
