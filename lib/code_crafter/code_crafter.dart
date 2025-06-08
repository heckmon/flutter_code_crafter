import './code_crafter_controller.dart';
import '../utils/shared.dart';
import '../gutter/gutter.dart';
import '../gutter/gutter_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeCrafter extends StatefulWidget {
  final CodeCrafterController controller;
  final TextStyle? textStyle;
  final Color? cursorColor, selectionColor, selectionHandleColor;
  final Map<String, TextStyle>? editorTheme;
  final int tabSize;
  final GutterStyle? gutterStyle;
  final bool enableBreakPoints;
  final bool enableFolding;
  const CodeCrafter({
    super.key,
    required this.controller,
    this.textStyle,
    this.gutterStyle,
    this.editorTheme,
    this.selectionHandleColor,
    this.selectionColor,
    this.cursorColor,
    this.enableBreakPoints = true,
    this.enableFolding = true,
    this.tabSize = 4,
  });

  @override
  State<CodeCrafter> createState() => _CodeCrafterState();
}

class _CodeCrafterState extends State<CodeCrafter> {
  String text = '';
  late final FocusNode _keyboardFocus, _codeFocus;

  @override
  void initState() {
    _keyboardFocus = FocusNode();
    _codeFocus = FocusNode();
    Shared().theme = widget.editorTheme ?? {};
    Shared().textStyle = widget.textStyle;
    Shared().controller = widget.controller;
    widget.controller.addListener(() {
      text = widget.controller.text;
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CodeCrafter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textStyle != oldWidget.textStyle) {
      Shared().textStyle = widget.textStyle;
    }

    if (widget.editorTheme != oldWidget.editorTheme) {
      Shared().theme = widget.editorTheme ?? {};
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Shared().constraints = constraints;
        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => _codeFocus.requestFocus(),
                child: Container(
                  color: widget.editorTheme?['root']?.backgroundColor ?? Colors.black,
                ),
              ),
              SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Gutter(
                      widget.gutterStyle ?? GutterStyle(
                        foldedIconColor: widget.editorTheme?['root']?.color ?? Colors.grey,
                        unfoldedIconColor: widget.editorTheme?['root']?.color ?? Colors.grey,
                      ),
                      widget.enableBreakPoints,
                      widget.enableFolding
                    ),
                    Expanded(
                      child: KeyboardListener(
                        focusNode: _keyboardFocus,
                        onKeyEvent: (value){
                          if(value is KeyDownEvent){
                            if(value.logicalKey == LogicalKeyboardKey.tab){
                              int cursorPosition = widget.controller.selection.baseOffset;
                              String currText = widget.controller.text;
                              widget.controller.text = "${currText.substring(0, cursorPosition)}${" " * widget.tabSize}${currText.substring(cursorPosition)}";
                              _keyboardFocus.previousFocus();
                              widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: cursorPosition + widget.tabSize));
                            }
                          }
                        } ,
                        child: Theme(
                          data: ThemeData(
                            textSelectionTheme: TextSelectionThemeData(
                              selectionColor: widget.selectionColor,
                              selectionHandleColor: widget.selectionHandleColor
                            )
                          ),
                          child: TextField(
                            onChanged: (value) {
                              widget.controller.refresh();
                            },
                            focusNode: _codeFocus,
                            scrollPhysics: NeverScrollableScrollPhysics(),
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                            ),
                            maxLines: null,
                            showCursor: true,
                            style: widget.textStyle ?? TextStyle(
                              height: 1.5,
                              fontSize: 14,
                            ),
                            cursorHeight: widget.textStyle?.fontSize ?? 14,
                            controller: widget.controller,
                            cursorColor:widget.cursorColor ?? widget.editorTheme?['root']?.color ?? Colors.white,
                            cursorWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}