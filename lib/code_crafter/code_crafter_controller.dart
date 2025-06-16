import '../utils/utils.dart';
import '../utils/shared.dart';
import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';

class CodeCrafterController extends TextEditingController{

  Mode? _language;
  Mode? get language => _language;

  String? _langId;
  
  set language(Mode? language){
    if(language == _language) return; 
    if(language != null){
      _langId = language.hashCode.toString();
      highlight.registerLanguage(_langId!, language);
    }
    _language = language;
    notifyListeners();
  }
  
  Map<String, TextStyle> get editorTheme => Shared().theme;
  TextStyle? get textStyle => Shared().textStyle;
  
  @override
  set value(TextEditingValue newValue) {
    final oldValue = super.value;
    if (
        newValue.text.length > oldValue.text.length && 
        newValue.selection.baseOffset > 0 &&
        newValue.text.substring(0, newValue.selection.baseOffset).endsWith('\n')
      ){
      final cursorPosition = newValue.selection.baseOffset;
      final textBeforeCursor = newValue.text.substring(0, cursorPosition);
      final textAfterCursor = newValue.text.substring(cursorPosition);

      final lines = textBeforeCursor.split('\n');
      if (lines.length < 2) {
        super.value = newValue;
        return;
      }
      final prevLine = lines[lines.length - 2];
      final indentMatch = RegExp(r'^\s*').firstMatch(prevLine);
      final prevIndent = indentMatch?.group(0) ?? '';
      final shouldIndent = RegExp(r'[:{[(]\s*$').hasMatch(prevLine);
      final extraIndent = shouldIndent ? ' ' * Shared().tabSize : '';
      final indent = prevIndent + extraIndent;
      final openToClose = {'{': '}', '(': ')', '[': ']'};
      final lastChar = prevLine.trimRight().isNotEmpty ? prevLine.trimRight().characters.last : null;
      final nextChar = textAfterCursor.trimLeft().isNotEmpty ? textAfterCursor.trimLeft().characters.first : null;
      final isBracketOpen = openToClose.containsKey(lastChar);
      final isNextClosing = isBracketOpen && openToClose[lastChar] == nextChar;
      String newText;
      int newOffset;
      if (isBracketOpen && isNextClosing) {
        newText = '$textBeforeCursor$indent\n$prevIndent$textAfterCursor';
        newOffset = cursorPosition + indent.length;
      } else {
        newText = '$textBeforeCursor$indent$textAfterCursor';
        newOffset = cursorPosition + indent.length;
      }

      super.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
      return;
    }

    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }){ 
      final List<String> lines = text.isNotEmpty ? text.split("\n") : [];
      final foldedRanges = Shared().lineStates.value
        .where((line) => line.foldRange?.isFolded == true)
        .map((line) => line.foldRange!)
        .toList();

      foldedRanges.sort((a, b) => a.startLine.compareTo(b.startLine));
      final filteredFolds = <FoldRange>[];
      for (final fold in foldedRanges) {
        bool isNested = filteredFolds.any((parent) =>
          fold.startLine >= parent.startLine && fold.endLine <= parent.endLine);
        if (!isNested) filteredFolds.add(fold);
      }
      filteredFolds.sort((a, b) => b.startLine.compareTo(a.startLine));

      for (final fold in filteredFolds) {
        int start = fold.startLine - 1;
        int end = fold.endLine;
        if (start >= 0 && end <= lines.length && start < end) {
          lines[start] = "${lines[start]}...${'\u200D' * ((lines.sublist(start+1, end).join('\n').length) - 2)}";
          lines.removeRange(start + 1, end);
        }
      }

      String newText = lines.join('\n');

      TextStyle baseStyle =  TextStyle(
        color: editorTheme['root']?.color,
        height: 1.5,
      );

      if(textStyle != null){
        baseStyle = baseStyle.merge(textStyle);
      }
      
      if(Shared().aiResponse != null && newText.isNotEmpty){
        final int cursorPosition = selection.baseOffset;
        final String textBeforeCursor = newText.substring(0, cursorPosition);
        final String textAfterCursor = newText.substring(cursorPosition);
        final String lastTypedChar = textBeforeCursor.isNotEmpty ? textBeforeCursor.characters.last.replaceAll("\n", '') : '';
        final List<Node>? beforeCursorNodes = highlight.parse(textBeforeCursor, language: _langId).nodes;

        if(Shared().aiResponse![0] == lastTypedChar){
          Shared().aiResponse = Shared().aiResponse!.substring(1);
        }
        else if(lastTypedChar.trim().isNotEmpty){
          Shared().aiResponse = null;
        }

        TextSpan aiOverlay = TextSpan(
          text: Shared().aiResponse,
          style: Shared().aiOverlayStyle ?? TextStyle(color: Colors.grey,fontStyle: FontStyle.italic)
        );
        final List<Node>? afterCursorNodes = highlight.parse(textAfterCursor,language: _langId).nodes;

        if(beforeCursorNodes != null){
          if(cursorPosition != selection.baseOffset){
            Shared().aiResponse = null;
          }
          return TextSpan(
            style: baseStyle,
            children: [
              ..._convert(beforeCursorNodes),
              aiOverlay,
              ..._convert(afterCursorNodes ?? <Node>[])
            ]
          );
        }
      }

      final List<Node>? nodes = highlight.parse(newText, language: _langId).nodes;
      if(nodes != null && editorTheme.isNotEmpty){
        return TextSpan(
          style: baseStyle,
          children: _convert(nodes)
        );
      }
      else{
        return TextSpan(text: text, style: textStyle);
      }
    }

  List<TextSpan> _convert(List<Node> nodes) {
    List<TextSpan> spans = [];
    var currentSpans = spans;
    List<List<TextSpan>> stack = [];

    void traverse(Node node) {
      if (node.value != null && editorTheme.isNotEmpty) {
        currentSpans.add(node.className == null
          ? TextSpan(text: node.value)
          : TextSpan(text: node.value, style: editorTheme[node.className!]));
      } else if (node.children != null) {
        List<TextSpan> tmp = [];
        currentSpans.add(TextSpan(children: tmp, style: editorTheme[node.className!]));
        stack.add(currentSpans);
        currentSpans = tmp;

        for (var n in node.children!) {
          traverse(n);
          if (n == node.children!.last) {
            currentSpans = stack.isEmpty ? spans : stack.removeLast();
          }
        }
      }
    }

    for (var node in nodes) {
      traverse(node);
    }

    return spans;
  }

  void refresh(){
    notifyListeners();
  }
}