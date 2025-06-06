import '../code_crafter/code_crafter_controller.dart';
import './utils.dart';
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
