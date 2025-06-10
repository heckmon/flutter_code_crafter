import '../code_crafter/code_crafter_controller.dart';
import './utils.dart';
import 'package:flutter/material.dart';

class Shared {
  static final Shared _instance = Shared._internal();
  factory Shared() => _instance;
  Shared._internal();

  String fullText = '', visibleText = '';
  double gutterWidth = 65;
  Map<String, TextStyle> theme = {};
  TextStyle? textStyle;
  int tabSize = 0;
  CodeCrafterController controller = CodeCrafterController();
  BoxConstraints constraints = BoxConstraints();
  ValueNotifier<List<LineState>> lineStates = ValueNotifier([]);
}
