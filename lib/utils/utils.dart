import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class EditorField {
  // Callbacks
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final void Function()? onEditingComplete;
  final void Function(String)? onSubmitted;
  final void Function(PointerDownEvent)? onTapOutside;

  // Keyboard & input
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization? textCapitalization;
  final bool? obscureText;
  final bool? enableSuggestions;
  final bool? autocorrect;

  // Layout & appearance
  final InputDecoration? decoration;
  final TextAlign? textAlign;
  final TextStyle? style;
  final TextDirection? textDirection;
  final TextAlignVertical? textAlignVertical;
  final bool? expands;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;

  // Cursor & selection
  final bool? showCursor;
  final double? cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final bool? enableInteractiveSelection;
  final TextSelectionControls? selectionControls;

  // Misc
  final ScrollPhysics? scrollPhysics;
  final ScrollController? scrollController;
  final SmartQuotesType? smartQuotesType;
  final SmartDashesType? smartDashesType;
  final Iterable<String>? autofillHints;
  final String? restorationId;
  final MouseCursor? mouseCursor;
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  const EditorField({
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onSubmitted,
    this.onTapOutside,
    this.keyboardType,
    this.inputFormatters,
    this.decoration,
    this.obscureText,
    this.enableSuggestions,
    this.textCapitalization,
    this.autocorrect,
    this.textInputAction,
    this.textAlign,
    this.textAlignVertical,
    this.style,
    this.textDirection,
    this.expands,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.maxLengthEnforcement,
    this.showCursor,
    this.cursorWidth,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.enableInteractiveSelection,
    this.selectionControls,
    this.scrollPhysics,
    this.scrollController,
    this.smartQuotesType,
    this.smartDashesType,
    this.autofillHints,
    this.restorationId,
    this.mouseCursor,
    this.contextMenuBuilder,
  });

  TextField build({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool autofocus,
    required bool readOnly,
    required TextStyle? fallbackStyle,
    required Color? fallbackCursorColor,
    required Map<String, TextStyle>? editorTheme,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      onTapOutside: onTapOutside,
      keyboardType: keyboardType ?? TextInputType.multiline,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      obscureText: obscureText ?? false,
      enableSuggestions: enableSuggestions ?? true,
      autocorrect: autocorrect ?? true,
      textInputAction: textInputAction,
      textAlign: textAlign ?? TextAlign.start,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      style: style ?? fallbackStyle ?? const TextStyle(fontSize: 14, height: 1.5),
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      showCursor: showCursor ?? true,
      cursorWidth: cursorWidth ?? 2,
      cursorHeight: cursorHeight ?? fallbackStyle?.fontSize ?? 14,
      cursorRadius: cursorRadius,
      cursorColor: cursorColor ?? fallbackCursorColor ?? editorTheme?['root']?.color ?? Colors.white,
      expands: expands ?? false,
      decoration: decoration?.copyWith(
        isCollapsed: true,
        border: InputBorder.none,
      ) ?? const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
      ),
      scrollPhysics: scrollPhysics ?? const NeverScrollableScrollPhysics(),
      scrollController: scrollController,
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      autofillHints: autofillHints,
      restorationId: restorationId,
      mouseCursor: mouseCursor,
      contextMenuBuilder: contextMenuBuilder,
    );
  }
}
