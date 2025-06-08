class LineState {
  final int lineNumber;
  final bool hasBreakpoint;

  FoldRange? foldRange;

  LineState({
    required this.lineNumber,
    this.hasBreakpoint = false,
  });
}

class FoldRange {
  final int startLine, endLine;
  bool isFolded;
  List<String> foldedLines = [];
  
  FoldRange(
    this.startLine,
    this.endLine,{this.isFolded = false});
}