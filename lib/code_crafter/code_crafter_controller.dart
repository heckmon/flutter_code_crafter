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
    final TextEditingValue oldValue = super.value;
    const pairs = {'(': ')', '{': '}', '[': ']', '"': '"', "'": "'"};
    final openers  = pairs.keys.toSet();
    final closers  = pairs.values.toSet();

    if (newValue.text.length == oldValue.text.length + 1 &&
        newValue.selection.baseOffset > 0) {

      final cursorPos   = newValue.selection.baseOffset;
      final inserted    = newValue.text[cursorPos - 1];

      if (openers.contains(inserted)) {
        final closing = pairs[inserted]!;
        final before  = newValue.text.substring(0, cursorPos);
        final after   = newValue.text.substring(cursorPos);

        super.value = TextEditingValue(
          text:  '$before$closing$after',
          selection: TextSelection.collapsed(offset: cursorPos),
        );
        return;
      }

      if (closers.contains(inserted)) {
        final oldCursorPos = oldValue.selection.baseOffset;
        if (oldCursorPos < oldValue.text.length) {
          final charAfterCursor = oldValue.text[oldCursorPos];
          if (charAfterCursor == inserted) {
            super.value = TextEditingValue(
              text: oldValue.text,
              selection: TextSelection.collapsed(offset: oldCursorPos + 1),
            );
            return;
          }
        }
      }
    }

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

  Set<int> _findUnmatchedBrackets(String text) {
    final stack = <int>[];
    final unmatched = <int>{};
    const Map<String, String> pairs = {'(': ')', '{': '}', '[': ']', '<': '>', "'": "'", '"': '"'};
    final Set<String> openers = pairs.keys.toSet();
    final Set<String> closers = pairs.values.toSet();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (openers.contains(char)) {
        stack.add(i);
      } else if (closers.contains(char)) {
        if (stack.isEmpty) {
          unmatched.add(i);
        } else {
          final lastOpen = stack.last;
          final openChar = text[lastOpen];
          if (pairs[openChar] == char) {
            stack.removeLast();
          } else {
            unmatched.add(i);
          }
        }
      }
    }
    unmatched.addAll(stack);
    return unmatched;
  }

  int? _findMatchingBracket(String text, int pos) {
    const Map<String, String> pairs = {'(': ')', '{': '}', '[': ']', ')': '(', '}': '{', ']': '[', '<': '>', '>': '<'};
    const String openers = '({[<';

    if (pos < 0 || pos >= text.length) return null;

    final char = text[pos];
    if (!pairs.containsKey(char)) return null;

    final match = pairs[char]!;
    final isForward = openers.contains(char);

    int depth = 0;
    if (isForward) {
      for (int i = pos + 1; i < text.length; i++) {
        if (text[i] == char) depth++;
        if (text[i] == match) {
          if (depth == 0) return i;
          depth--;
        }
      }
    } else {
      for (int i = pos - 1; i >= 0; i--) {
        if (text[i] == char) depth++;
        if (text[i] == match) {
          if (depth == 0) return i;
          depth--;
        }
      }
    }
    return null;
  }


  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }){ 
    final int cursorPosition = selection.baseOffset;
    int? bracket1, bracket2;

    if (cursorPosition >= 0 && cursorPosition <= text.length) {
      final String? before = cursorPosition > 0 ? text[cursorPosition - 1] : null;
      final String? after = cursorPosition < text.length ? text[cursorPosition] : null;
      final int? pos = (before != null && '{}[]()<>'.contains(before)) ? cursorPosition - 1
        : (after != null && '{}[]()<>'.contains(after)) ? cursorPosition : null;

      if (pos != null) {
        final match = _findMatchingBracket(text, pos);
        if (match != null) {
          bracket1 = pos;
          bracket2 = match;
        }
      }
    }

    final List<String> lines = text.isNotEmpty ? text.split("\n") : [];
    final List<FoldRange> foldedRanges = Shared().lineStates.value
      .where((line) => line.foldRange?.isFolded == true)
      .map((line) => line.foldRange!)
      .toList();

    foldedRanges.sort((a, b) => a.startLine.compareTo(b.startLine));
    final filteredFolds = <FoldRange>[];
    for (final FoldRange fold in foldedRanges) {
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
    
    if(Shared().aiResponse != null && newText.isNotEmpty && Shared().aiResponse!.isNotEmpty){
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
    final Set<int> unmatchedBrackets = _findUnmatchedBrackets(text);
    if(nodes != null && editorTheme.isNotEmpty){
      return TextSpan(
        style: baseStyle,
        children: _convert(nodes, 0 , bracket1, bracket2, unmatchedBrackets)
      );
    }
    else{
      return TextSpan(text: text, style: textStyle);
    }
  }

  List<TextSpan> _convert(
      List<Node> nodes,
      [int startOffset = 0, int? b1, int? b2, Set<int> unmatched = const {}]
    ) {
    List<TextSpan> spans = [];
    int offset = startOffset;
    TextStyle? style;

    for (final node in nodes) {
      if (node.value != null) {
        for (int i = 0; i < node.value!.length; i++) {
          final globalIndex = offset + i;
          final char = node.value![i];
          final isMatch = (globalIndex == b1 || globalIndex == b2);
          final isUnmatched = unmatched.contains(globalIndex);
          if (isUnmatched) {
            style = const TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Colors.red
            );
          } else if (isMatch) {
            style = (editorTheme[node.className ?? '']?.merge(TextStyle(
                background: Paint()
                    ..style = PaintingStyle.stroke
                    ..color = editorTheme['root']?.color ?? Colors.white,
                )) ?? TextStyle(
                  background: Paint()
                    ..style = PaintingStyle.stroke
                    ..color = editorTheme['root']?.color ?? Colors.white,
                ));
          } else {
            style = editorTheme[node.className ?? ''];
          }
          
          spans.add(TextSpan(text: char, style: style));
        }

        offset += node.value!.length;
      } else if (node.children != null) {
          final innerSpans = _convert(node.children!, offset, b1, b2);
          spans.add(TextSpan(children: innerSpans, style: editorTheme[node.className ?? '']));
          offset += _textLengthFromSpans(innerSpans);
      }
    }

    return spans;
  }

  int _textLengthFromSpans(List<InlineSpan> spans) {
    int length = 0;
    for (final span in spans) {
      if (span is TextSpan && span.text != null) {
        length += span.text!.length;
      }
      if (span is TextSpan && span.children != null) {
        length += _textLengthFromSpans(span.children!);
      }
    }
    return length;
  }

  void refresh(){
    notifyListeners();
  }
}