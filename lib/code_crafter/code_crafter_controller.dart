import 'package:flutter_code_crafter/utils/shared.dart';
import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';

class CodeCrafterController extends TextEditingController{

  String? _language;
  String? get language => _language;

  set language(String? language){
    _language = language;
    notifyListeners();
  }
  
  Map<String, TextStyle> get editorTheme => Shared().theme;
  TextStyle? get textStyle => Shared().textStyle;

  
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }){ 
      TextStyle baseStyle =  TextStyle(
        color: editorTheme['root']?.color,
        height: 1.5,
      );

      final List<Node>? nodes = highlight.parse(text, language: language ?? "").nodes;
      if(nodes != null && editorTheme.isNotEmpty){
        if(textStyle != null){
          baseStyle = baseStyle.merge(textStyle);
        }
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

    traverse(Node node) {
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
