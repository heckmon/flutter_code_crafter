import 'package:flutter/material.dart';

class SuggestionStyle {
  final double elevation;
  final Color backgroundColor, focusColor, hoverColor, splashColor;
  final ShapeBorder shape;
  final TextStyle textStyle;

  SuggestionStyle({
    this.elevation = 6,
    required this.shape,
    required this.backgroundColor,
    required this.focusColor,
    required this.hoverColor,
    required this.splashColor,
    required this.textStyle
  });
}