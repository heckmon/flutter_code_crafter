import 'dart:async';
import 'dart:io';
import '../LSP/lsp.dart';
import '../utils/utils.dart';
import '../utils/shared.dart';
import '../gutter/gutter.dart';
import '../AI_completion/ai.dart';
import '../gutter/gutter_style.dart';
import './code_crafter_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeCrafter extends StatefulWidget {
  final CodeCrafterController controller;
  final String? initialText, filePath;
  final TextStyle? textStyle, aiCompletionTextStyle;
  final Color? cursorColor, selectionColor, selectionHandleColor;
  final Map<String, TextStyle>? editorTheme;
  final int tabSize;
  final GutterStyle? gutterStyle;
  final bool enableBreakPoints, enableFolding, autoFocus, readOnly;
  final bool wrapLines;
  final FocusNode? focusNode;
  final EditorField? editorField;
  final AiCompletion? aiCompletion;
  final LspConfig? lspConfig;
  const CodeCrafter({
    super.key,
    required this.controller,
    this.initialText,
    this.filePath,
    this.focusNode,
    this.textStyle,
    this.gutterStyle,
    this.editorTheme,
    this.aiCompletion,
    this.aiCompletionTextStyle,
    this.lspConfig,
    this.selectionHandleColor,
    this.selectionColor,
    this.cursorColor,
    this.enableBreakPoints = true,
    this.enableFolding = true,
    this.wrapLines = false,
    this.autoFocus = false,
    this.readOnly = false,
    this.tabSize = 3,
    this.editorField
  });

  @override
  State<CodeCrafter> createState() => _CodeCrafterState();
}

class _CodeCrafterState extends State<CodeCrafter> {
  late final FocusNode _keyboardFocus, _codeFocus;
  double gutterWidth = Shared().gutterWidth;
  Map<String, String> cachedResponse = {};
  Timer? _debounceTimer;
  String _value = '';
  int _cursorPostion = 0;

  @override
  void initState() {
    _keyboardFocus = FocusNode();
    _codeFocus = widget.focusNode ?? FocusNode();
    widget.controller.text = widget.initialText ?? '';
    if(widget.initialText != null && widget.filePath != null) {
      throw Exception('Initial text and file path cannot be both provided. Please provide either initialText or filePath.');
    }
    if(widget.lspConfig != null){
      if((widget.lspConfig!.filePath != widget.filePath) || widget.filePath == null){ 
        throw Exception('File path in LspConfig does not match the provided filePath in CodeCrafter.');
      }
      (() async{
        try {
          if(widget.lspConfig is LspSocketConfig){
            await (widget.lspConfig as LspSocketConfig).connect();  
          }
          await widget.lspConfig!.initialize();
          await widget.lspConfig!.openDocument();
          final content = await File(widget.lspConfig!.filePath).readAsString();
          widget.controller.value = TextEditingValue(
            text: content,
            selection: TextSelection.collapsed(offset: content.length)
          );
        } catch (e) {
          widget.controller.text = '';
        }
      })();
    }
    _value = widget.controller.text;
    _cursorPostion = widget.controller.selection.baseOffset;

    Shared().theme = widget.editorTheme ?? {};
    Shared().textStyle = widget.textStyle;
    Shared().aiOverlayStyle = widget.aiCompletionTextStyle;
    Shared().controller = widget.controller;
    Shared().tabSize = widget.tabSize;
    widget.controller.addListener(() {
      if(widget.lspConfig != null) {
        (() async{
          await widget.lspConfig!.updateDocument(widget.controller.text);
          final text = widget.controller.text;
          final cursorOffset = widget.controller.selection.baseOffset;
          final lines = text.substring(0, cursorOffset).split('\n');
          final line = lines.length - 1;
          final character = lines.isNotEmpty ? lines.last.length : 0;
          final data = await widget.lspConfig!.getCompletions(line, character);
          print(data);
        })();
      }

      if(gutterWidth != Shared().gutterWidth) {
        setState(() => gutterWidth = Shared().gutterWidth);
      }
      if(_value == widget.controller.text && _cursorPostion != widget.controller.selection.baseOffset){
        Shared().aiResponse = null;
      }
      if(_value != widget.controller.text && (widget.aiCompletion?.enableCompletion ?? false)){
        final String text = widget.controller.text;
        final int cursorPosition = widget.controller.selection.baseOffset;
        final String codeToSend = "${text.substring(0, cursorPosition)}<|CURSOR|>${text.substring(cursorPosition)}";

        _debounceTimer?.cancel();

        _debounceTimer = Timer(
          Duration(milliseconds: widget.aiCompletion!.debounceTime),
          () async {
            Shared().aiResponse = await _getCachedRsponse(codeToSend);
            setState(() {});
          }
        );
        _value = widget.controller.text;
      }
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
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<String> _getCachedRsponse(String codeToSend) async{
    final String key = codeToSend.hashCode.toString();
    if(cachedResponse.containsKey(key)){
      return cachedResponse[key]!;
    }
    final String aiResponse = await widget.aiCompletion!.model.completionResponse(codeToSend);
    cachedResponse[key] = aiResponse;
    return aiResponse;
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
                              _keyboardFocus.previousFocus();
                              widget.controller.value = TextEditingValue(
                                text: currText.replaceRange(cursorPosition, cursorPosition, ' ' * widget.tabSize),
                                selection: TextSelection.collapsed(offset: cursorPosition + widget.tabSize)
                              );
                              return;
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
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: widget.wrapLines ? constraints.maxWidth - gutterWidth : double.maxFinite,
                              child: widget.editorField?.build(
                                controller: widget.controller,
                                focusNode: _codeFocus,
                                autofocus: widget.autoFocus,
                                readOnly: widget.readOnly,
                                fallbackStyle: widget.textStyle,
                                fallbackCursorColor: widget.cursorColor,
                                editorTheme: widget.editorTheme,
                              ) ?? TextField(
                                controller: widget.controller,
                                focusNode: _codeFocus,
                                autofocus: widget.autoFocus,
                                readOnly: widget.readOnly,
                                scrollPhysics: const NeverScrollableScrollPhysics(),
                                keyboardType: TextInputType.multiline,
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                ),
                                maxLines: null,
                                showCursor: true,
                                style: widget.textStyle ?? const TextStyle(height: 1.5, fontSize: 14),
                                cursorHeight: widget.textStyle?.fontSize ?? 14,
                                cursorColor: widget.cursorColor ?? widget.editorTheme?['root']?.color ?? Colors.white,
                                cursorWidth: 2,
                              ),
                            ),
                          )
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