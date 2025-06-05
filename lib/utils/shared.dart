import 'package:flutter_code_crafter/code_crafter/code_crafter_controller.dart';
import 'package:flutter_code_crafter/gutter/gutter.dart';
import 'package:flutter/material.dart';

class Shared {
  static final Shared _instance = Shared._internal();
  factory Shared() => _instance;
  Shared._internal();

  Map<String, TextStyle> theme = {};
  TextStyle? textStyle;
  CodeCrafterController controller = CodeCrafterController();
  BoxConstraints constraints = BoxConstraints();
  ValueNotifier<List<LineState>> lineStates = ValueNotifier([]);
}
