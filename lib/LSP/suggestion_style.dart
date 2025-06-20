import 'package:flutter/material.dart';

sealed class OverlayStyle{
  final double elevation;
  final Color backgroundColor, focusColor, hoverColor, splashColor;
  final ShapeBorder shape;
  final TextStyle textStyle;
  OverlayStyle({
    this.elevation = 6,
    required this.shape,
    required this.backgroundColor,
    required this.focusColor,
    required this.hoverColor,
    required this.splashColor,
    required this.textStyle
  });
}

class SuggestionStyle extends OverlayStyle{
  SuggestionStyle({
    super.elevation,
    required super.shape,
    required super.backgroundColor,
    required super.focusColor,
    required super.hoverColor,
    required super.splashColor,
    required super.textStyle
  });
}

class HoverDetailsStyle extends OverlayStyle{
  HoverDetailsStyle({
    super.elevation,
    required super.shape,
    required super.backgroundColor,
    required super.focusColor,
    required super.hoverColor,
    required super.splashColor,
    required super.textStyle
  });
}