import '../code_crafter/code_crafter_controller.dart';
import './utils.dart';
import 'package:flutter/material.dart';

class Shared {
  static final Shared _instance = Shared._internal();
  factory Shared() => _instance;
  Shared._internal();

  String? aiResponse;
  double gutterWidth = 65;
  Map<String, TextStyle> theme = {};
  TextStyle? textStyle, aiOverlayStyle;
  int tabSize = 0;
  List<LspErrors> diagnostics = [];
  bool enableRulerLines = true;
  CodeCrafterController controller = CodeCrafterController();
  ValueNotifier<List<LineState>> lineStates = ValueNotifier([]);
}
