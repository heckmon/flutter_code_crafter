import 'package:flutter/material.dart';

class GutterStyle{
  final TextStyle? lineNumberStyle;
  final Color breakpointColor, unfilledBreakpointColor;
  final Color foldedIconColor, unfoldedIconColor;
  final Color? dividerColor;
  final double? breakpointSize, gutterWidth, foldingIconSize;
  final IconData breakpointIcon, unfilledBreakpointIcon;
  final IconData unfoldedIcon, foldedIcon;
  GutterStyle({
    this.lineNumberStyle,
    this.dividerColor,
    this.gutterWidth,
    this.breakpointIcon = Icons.circle,
    this.unfilledBreakpointIcon = Icons.circle_outlined,
    this.foldedIcon = Icons.chevron_right_outlined,
    this.unfoldedIcon = Icons.keyboard_arrow_down_outlined,
    this.breakpointSize,
    this.foldingIconSize,
    this.breakpointColor = Colors.red,
    this.unfilledBreakpointColor = Colors.transparent,
    this.foldedIconColor = Colors.grey,
    this.unfoldedIconColor = Colors.grey,
  });
}