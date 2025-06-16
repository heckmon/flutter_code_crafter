import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';

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
  OverlayEntry? _suggestionOverlay;
  List<String> _suggestions = [];
  bool _recentlyTyped = false;

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
          final content = await File(widget.filePath!).readAsString();
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
    String oldVal = '';
    widget.controller.addListener(() {
      if(widget.lspConfig != null) {
        (() async{
          await widget.lspConfig!.updateDocument(widget.controller.text);
          final currentText = widget.controller.text;
          final cursorOffset = widget.controller.selection.baseOffset;
          final lines = currentText.substring(0, cursorOffset).split('\n');
          final line = lines.length - 1;
          final character = lines.isNotEmpty ? lines.last.length : 0;
          final suggestion = await widget.lspConfig!.getCompletions(line, character);
          _recentlyTyped = currentText.length > oldVal.length;
          oldVal = currentText;
          if (_recentlyTyped && suggestion.isNotEmpty && cursorOffset > 0) {
            _suggestions = suggestion;
            final triggerChar = currentText[cursorOffset - 1];
            if([' ', '\n', ')', ']', '}', ';', ':', ''].contains(triggerChar)) {
              _hideSuggestionOverlay();
              return;
            }
            if(mounted) _showSuggestionOverlay();
          } else {
            _hideSuggestionOverlay();
          }
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

  void _insertSuggestion(String suggestion) {
    final text = widget.controller.text;
    final cursorOffset = widget.controller.selection.baseOffset;
    final newText = text.replaceRange(cursorOffset, cursorOffset, suggestion);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset + suggestion.length),
    );
  }

  void _hideSuggestionOverlay() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  RenderEditable? _findRenderEditable(BuildContext root) {
    RenderEditable? result;
    void visitor(Element element) {
      if (result != null) return;
      final ro = element.renderObject;
      if (ro is RenderEditable) {
        result = ro;
        return;
      }
      element.visitChildElements(visitor);
    }

    root.visitChildElements(visitor);
    return result;
  }


  Rect _globalCaretRect() {
    final ctx = _codeFocus.context;
    if (ctx == null) return Rect.zero;

    final renderEditable = _findRenderEditable(ctx);
    if (renderEditable == null) {
      return Rect.zero;
    }

    final caret = renderEditable.getLocalRectForCaret(
      TextPosition(offset: widget.controller.selection.baseOffset),
    );

    final globalTopLeft = renderEditable.localToGlobal(caret.topLeft);
    final rect = Rect.fromLTWH(
      globalTopLeft.dx,
      globalTopLeft.dy,
      caret.width,
      caret.height,
    );
    return rect;
  }


  void _showSuggestionOverlay() {
    _suggestionOverlay?.remove();

    final overlay = Overlay.of(context);
    final caretGlobal = _globalCaretRect();
    const overlayWidth = 250.0;
    const overlayHeight = 300.0;
    final screenHeight = MediaQuery.of(context).size.height;
    const gap = 4;
    final bool showAbove = caretGlobal.bottom + gap + overlayHeight > screenHeight;

    final double top = showAbove
        ? caretGlobal.top - gap - overlayHeight
        : caretGlobal.bottom + gap;

    final double left = caretGlobal.left;

    _suggestionOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top:  top,
        width: overlayWidth,
        height: overlayHeight,
        child: Material(
          elevation: 6,
          color: Colors.transparent,
          child: Card(
            color: Shared().theme['root']?.backgroundColor?.withAlpha(220),
            shape: BeveledRectangleBorder(
              side: BorderSide(
                color: Shared().theme['root']?.color ?? Colors.white,
                width: 0.5,
              ),
            ),
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (_, i) => InkWell(
                hoverColor: Colors.blueAccent.withAlpha(50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Row(
                    children: [
                      Text(
                        _suggestions[i],
                        style: TextStyle(
                          color: Shared().theme['root']?.color ?? Colors.white,
                          fontSize: (widget.textStyle?.fontSize ?? 14) - 2,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  _insertSuggestion(_suggestions[i]);
                  _hideSuggestionOverlay();
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_suggestionOverlay!);
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
                            if(value.logicalKey == LogicalKeyboardKey.escape){
                              _hideSuggestionOverlay();
                              return;
                            }
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