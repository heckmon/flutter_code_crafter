import './shared.dart';

class LineState {
  final int lineNumber;
  final bool hasBreakpoint;
  String code = "";

  FoldRange? foldRange;

  LineState({
    required this.lineNumber,
    this.hasBreakpoint = false,
  }) {
    code = Shared().controller.text.split('\n')[lineNumber - 1];
  }
}

class FoldRange {
  final int startLine, endLine;
  bool isFolded;
  List<String> foldedLines = [];
  
  FoldRange(
    this.startLine,
    this.endLine,{this.isFolded = false});
}