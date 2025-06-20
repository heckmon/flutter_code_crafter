import 'dart:io';
import 'dart:async';
import '../LSP/lsp.dart';
import '../utils/utils.dart';
import '../utils/shared.dart';
import '../gutter/gutter.dart';
import '../AI_completion/ai.dart';
import '../gutter/gutter_style.dart';
import '../LSP/suggestion_style.dart';
import './code_crafter_controller.dart';
import 'package:flutter/rendering.dart';
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
  final bool wrapLines, enableRulerLines;
  final FocusNode? focusNode;
  final EditorField? editorField;
  final AiCompletion? aiCompletion;
  final LspConfig? lspConfig;
  final SuggestionStyle? suggestionStyle;
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
    this.suggestionStyle,
    this.selectionHandleColor,
    this.selectionColor,
    this.cursorColor,
    this.enableBreakPoints = true,
    this.enableFolding = true,
    this.enableRulerLines = true,
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
  late final FocusNode _keyboardFocus, _codeFocus, _suggestionFocus;
  double gutterWidth = Shared().gutterWidth;
  Map<String, String> cachedResponse = {};
  Timer? _debounceTimer;
  String _value = '';
  int _cursorPosition = 0, _selected = 0;
  OverlayEntry? _suggestionOverlay;
  List<dynamic> _suggestions = [];
  List<LspErrors> _diagnostics = [];
  bool _recentlyTyped = false, _suggestionShown = false;
  Rect _caretRect = Rect.zero;
  String? content;

  @override
  void initState() {
    _keyboardFocus = FocusNode();
    _suggestionFocus = FocusNode();
    _codeFocus = widget.focusNode ?? FocusNode();
    widget.controller.text = widget.initialText ?? '';
    if(widget.lspConfig != null){
      widget.lspConfig!.responses.listen((data){
        if(data['method'] == 'textDocument/publishDiagnostics'){
          final diagnostics = data['params']['diagnostics'] as List;
          _diagnostics.clear();
          Shared().diagnostics.clear();
          if(diagnostics.isNotEmpty){
            final List<LspErrors> errors = [];
            for(final (item as Map<String, dynamic>) in diagnostics){
              errors.add(
                LspErrors(
                  severity: item['severity'], 
                  range: item['range'],
                  message: item['message']
                )
              );
            }
            _diagnostics = List.from(errors);
            Shared().diagnostics = _diagnostics;
          }
        }
      });
    }
    if(widget.filePath != null) {
      (() async {
         content = await File(widget.filePath!).readAsString();
         widget.controller.value = TextEditingValue(
            text: content ?? '',
            selection: TextSelection.collapsed(offset: content?.length ?? 0)
          );
      })();
    }
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
        } catch (e) {
          widget.controller.text = '';
        }
      })();
    }

    Shared().theme = widget.editorTheme ?? {};
    Shared().textStyle = widget.textStyle;
    Shared().aiOverlayStyle = widget.aiCompletionTextStyle;
    Shared().controller = widget.controller;
    Shared().tabSize = widget.tabSize;
    Shared().enableRulerLines = widget.enableRulerLines;
    String oldVal = '';
    _value = widget.controller.text;
    widget.controller.addListener(() {
      final currentText = widget.controller.text;
      final cursorOffset = widget.controller.selection.baseOffset;
      final lines = currentText.substring(0, cursorOffset).split('\n');
      final line = lines.length - 1;
      final prefix = _getCurrentWordPrefix(currentText,  cursorOffset);
      final character = lines.isNotEmpty ? lines.last.length : 0;
      _recentlyTyped = currentText.length > oldVal.length;
      oldVal = currentText;

      if(widget.lspConfig == null){
        final RegExp regExp = RegExp(r'\b\w+\b');
        final List<String> words = regExp.allMatches(widget.controller.text).map((m) => m.group(0)!).toList();
        String currentWord = '';
        if (widget.controller.text.isNotEmpty) {
          final match = RegExp(r'\w+$').firstMatch(widget.controller.text);
          if (match != null) {
            currentWord = match.group(0)!;
          }
        }

        _suggestions.clear();
        for (var i in words) {
          if (!_suggestions.contains(i) && i != currentWord) {
            _suggestions.add(i);
          }
        }

        if (prefix.isNotEmpty) {
          _suggestions = _suggestions.where((s) => s.startsWith(prefix)).toList();
        }

        if (_recentlyTyped && _suggestions.isNotEmpty && cursorOffset > 0) {
          _sortSuggestions(prefix);
          final triggerChar = currentText[cursorOffset - 1];
          if (!RegExp(r'[a-zA-Z]').hasMatch(triggerChar)) {
            _hideSuggestionOverlay();
            return;
          }
          if (mounted) _showSuggestionOverlay();
        } else {
          _hideSuggestionOverlay();
        }
      }
    _cursorPosition = widget.controller.selection.baseOffset;
      if(widget.lspConfig != null && widget.controller.selection.baseOffset > 0) {
        (() async{
          await widget.lspConfig!.updateDocument(widget.controller.text);
          final suggestion = await widget.lspConfig!.getCompletions(line, character);
          if (_recentlyTyped && suggestion.isNotEmpty && cursorOffset > 0) {
            _suggestions = suggestion;
            _selected = 0;
            _sortSuggestions(prefix);
            final triggerChar = currentText[cursorOffset - 1];
            if(!RegExp(r'[a-zA-Z._$]').hasMatch(triggerChar)) {
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
      if(_value == widget.controller.text && _cursorPosition != widget.controller.selection.baseOffset){
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
    _keyboardFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  String _getCurrentWordPrefix(String text, int offset) {
    final beforeCursor = text.substring(0, offset);
    final match = RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*)$').firstMatch(beforeCursor);
    return match?.group(0) ?? '';
  }

  void _sortSuggestions(String prefix) {
    _suggestions.sort((a, b) {
      final aStartsWith = a is LspCompletion ? 
          a.label.toLowerCase().startsWith(prefix.toLowerCase())
          : a.toLowerCase().startsWith(prefix.toLowerCase());
      final bStartsWith = b is LspCompletion ? 
          b.label.toLowerCase().startsWith(prefix.toLowerCase())
          : b.toLowerCase().startsWith(prefix.toLowerCase());
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      return a is LspCompletion
      ? b.label.compareTo(a.label)
      : b.compareTo(a);
    });
  }

  void _insertSuggestion(String suggestion) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    int start = cursorPos - 1;
    while (start >= 0 && !_isWordBoundary(text[start])) {
      start--;
    }
    start++;
    final newText = text.replaceRange(start, cursorPos, suggestion);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + suggestion.length),
    );
  }

  bool _isWordBoundary(String char) {
    return char == ' ' || char == '\n' || char == '\t' || char == '(' || 
          char == ')' || char == '{' || char == '}' || char == ';' || 
          char == ',' || char == '.' || char == '"' || char == '\'';
  }

  void _hideSuggestionOverlay() {
    _suggestionShown = false;
    _suggestionFocus.unfocus();
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

    final RenderEditable? renderEditable = _findRenderEditable(ctx);
    if (renderEditable == null) {
      return Rect.zero;
    }

    final Rect caret = renderEditable.getLocalRectForCaret(
      TextPosition(offset: widget.controller.selection.baseOffset),
    );

    final Offset globalTopLeft = renderEditable.localToGlobal(caret.topLeft);
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
    _suggestionShown = true;
    final OverlayState overlay = Overlay.of(context);
    final Rect caretGlobal = _globalCaretRect();
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    const double overlayWidth = 250.0, maxOverlayHeight = 300.0;
    const int gap = 4;
    final bool showAbove = caretGlobal.bottom + gap + maxOverlayHeight > screenHeight;
    final bool showLeft = caretGlobal.left + overlayWidth > screenWidth;

    final double top = showAbove
      ? caretGlobal.top - gap - maxOverlayHeight
      : caretGlobal.bottom + gap;

    final double left = showLeft
      ? caretGlobal.left - overlayWidth + caretGlobal.width
      : caretGlobal.left;

    _suggestionOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top:  top,
        width: overlayWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxOverlayHeight,
          ),
          child: Card(
            elevation: widget.suggestionStyle?.elevation ?? 6,
            color: widget.suggestionStyle?.backgroundColor ?? Shared().theme['root']?.backgroundColor?.withAlpha(220)  ?? Colors.black87,
            shape: widget.suggestionStyle?.shape ?? BeveledRectangleBorder(
              side: BorderSide(
                color: Shared().theme['root']?.color ?? Colors.white,
                width: 0.2,
              ),
            ),
            child: Focus(
              child: ListView.builder(
                itemExtent: (widget.textStyle?.fontSize ?? 14) + 5,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  return InkWell(
                    autofocus: true,
                    focusNode: _selected == i ? _suggestionFocus : null,
                    focusColor: widget.suggestionStyle?.focusColor ?? Colors.blueAccent.withAlpha(50),
                    hoverColor: widget.suggestionStyle?.hoverColor ?? Colors.grey.withAlpha(15),
                    splashColor: widget.suggestionStyle?.splashColor ?? Colors.blueAccent.withAlpha(50),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Row(
                        children: [
                          _suggestions[i] is LspCompletion ? _suggestions[i].icon : const SizedBox(),
                          const SizedBox(width: 6),
                          Text(
                            _suggestions[i] is LspCompletion ? _suggestions[i].label : _suggestions[i],
                            overflow: TextOverflow.ellipsis,
                            style: widget.suggestionStyle?.textStyle ?? TextStyle(
                              color: Shared().theme['root']?.color ?? Colors.white,
                              fontSize: (widget.textStyle?.fontSize ?? 14) - 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _insertSuggestion(_suggestions[i] is LspCompletion ? _suggestions[i].label : _suggestions[i]);
                      _selected = i;
                      _hideSuggestionOverlay();
                      _codeFocus.requestFocus();
                    },
                  );
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
         WidgetsBinding.instance.addPostFrameCallback((_) {
          final rect = _globalCaretRect();
          if (rect != _caretRect) setState(() => _caretRect = rect);
        });
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
                              if(_suggestionShown){
                                _suggestionFocus.unfocus();
                                _hideSuggestionOverlay();
                                _codeFocus.requestFocus();
                              }
                            }

                            if(value.logicalKey == LogicalKeyboardKey.arrowUp){
                              if(_suggestionShown){
                                setState(() => _selected--);
                                _suggestionFocus.requestFocus();
                              }
                            }

                            if(value.logicalKey == LogicalKeyboardKey.arrowDown){
                              if(_suggestionShown){
                                setState(() => _selected++);
                                _suggestionFocus.requestFocus();
                              }
                            }

                            if(value.logicalKey == LogicalKeyboardKey.enter){
                              if(_suggestionShown) _suggestionFocus.requestFocus();
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
              if(widget.aiCompletion != null && widget.aiCompletion!.enableCompletion && Shared().aiResponse != null && Shared().aiResponse!.isNotEmpty)
                Positioned(
                  left: _caretRect.left,
                  right: _caretRect.right,
                  top: _caretRect.top + _caretRect.height + (Shared().aiResponse!.split('\n').length * (widget.textStyle?.fontSize ?? 14)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 55,
                        height: _caretRect.height,
                        child: TextButton(
                          style: ButtonStyle(
                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                              side: BorderSide(color: Colors.white, width: 0.2),
                            )),
                            backgroundColor: WidgetStatePropertyAll(Colors.blueAccent),
                            foregroundColor: WidgetStatePropertyAll(Colors.white),
                          ),
                          onPressed: (){
                            setState(() {
                              _insertSuggestion(Shared().aiResponse!);
                              Future.delayed(Duration.zero);
                              Shared().aiResponse = null;
                            });
                          }, 
                          child: const Text("Accept",style: TextStyle(fontSize: 9))
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 55,
                        height: _caretRect.height,
                        child: TextButton(
                          style: ButtonStyle(
                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                              side: BorderSide(color: Colors.white, width: 0.2),
                            )),
                            backgroundColor: WidgetStatePropertyAll(Colors.blueAccent),
                            foregroundColor: WidgetStatePropertyAll(Colors.white),
                          ),
                          onPressed: () => setState(() => Shared().aiResponse = null),
                          child: const Text("Reject", style: TextStyle(fontSize: 9))),
                      ),
                    ],
                  )
                ),
            ],
          ),
        );
      }
    );
  }
}