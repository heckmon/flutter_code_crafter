import 'dart:math';
import 'package:flutter_code_crafter/code_crafter/code_crafter_controller.dart';
import 'package:flutter_code_crafter/utils/shared.dart';
import 'package:flutter_code_crafter/gutter/gutter_style.dart';
import 'package:flutter/material.dart';


class Gutter extends StatefulWidget {
  final bool enableBreakPoints;
  final GutterStyle gutterStyle;
  const Gutter(this.gutterStyle,this.enableBreakPoints, {super.key});

  @override
  State<Gutter> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  final CodeCrafterController _controller = Shared().controller;
  late ValueNotifier<List<LineState>> _lineStates;
  TextPainter _textPainter = TextPainter();
  int lineNumber = 0;
  double? _gutterWidth;

  @override
  void initState() {
    final lineMetrics = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: _controller.text),
    )..layout();

    lineNumber = lineMetrics.computeLineMetrics().length;

    _lineStates = ValueNotifier(List.generate(lineNumber, (index) => LineState(lineNumber: index + 1)));
    _controller.addListener((){
      _textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: _controller.text,
        )
      )..layout();
      if(lineNumber != _textPainter.computeLineMetrics().length){
        final oldStates = _lineStates.value;
        final updatedStates = List.generate(_textPainter.computeLineMetrics().length, (index) {
          if (index < oldStates.length) {
            return oldStates[index];
          } else {
            return LineState(lineNumber: index + 1);
          }
        });

        setState(() {
          lineNumber = _textPainter.computeLineMetrics().length;
          _lineStates.value =  updatedStates;
          Shared().lineStates = _lineStates;
        });
      }
      _getFoldRanges(_controller.text, _lineStates);
      int digitCount = max(3, lineNumber.toString().length);
      TextPainter gutterPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: List.filled(digitCount, "8").join(),
          style: Shared().textStyle?.copyWith(height: 1.5) ?? TextStyle(height: 1.5)
        )
      )..layout();
      _gutterWidth = widget.gutterStyle.gutterWidth ?? gutterPainter.width * 2.1;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _gutterWidth,
      child: ValueListenableBuilder<List<LineState>>(
        valueListenable: _lineStates,
        builder: (context, lines, _) {
          return Column(
            children: lines.map((line){
              return GutterItem(
                lineNumberStyle: widget.gutterStyle.lineNumberStyle,
                onTap: () {
                  final index = line.lineNumber - 1;
                  final updated = List<LineState>.from(_lineStates.value);
                  updated[index] = LineState(
                    lineNumber: updated[index].lineNumber,
                    hasBreakpoint: !updated[index].hasBreakpoint,
                  );
                  _lineStates.value = updated;
                },
                leftItem: widget.enableBreakPoints ? GestureDetector(
                  onTap: () {
                    final index = line.lineNumber - 1;
                    final updated = List<LineState>.from(_lineStates.value);
                    updated[index] = LineState(
                      lineNumber: updated[index].lineNumber,
                      hasBreakpoint: !updated[index].hasBreakpoint,
                    );
                    _lineStates.value = updated;
                  },
                  child: Icon(
                    line.hasBreakpoint? 
                      widget.gutterStyle.breakpointIcon : widget.gutterStyle.unfilledBreakpointIcon,
                    size: ((){
                      if(widget.gutterStyle.breakpointSize != null){
                        return widget.gutterStyle.breakpointSize;
                      }
                      else if(widget.gutterStyle.lineNumberStyle?.fontSize != null){
                        double? breakpointSize = widget.gutterStyle.lineNumberStyle!.fontSize;
                        if(breakpointSize != null) {
                          return breakpointSize * 0.4;
                        }
                      }else if(Shared().textStyle?.fontSize != null){
                        return Shared().textStyle!.fontSize !* 0.6;
                      }else{
                        return 14 * 0.6;
                      }
                    })(),
                    color: line.hasBreakpoint ? 
                      widget.gutterStyle.breakpointColor : widget.gutterStyle.unfilledBreakpointColor,
                  ),
                ) : SizedBox.shrink(),
                line.lineNumber,
                rightItem: line.foldRange != null ? GestureDetector(
                  onTap: () {
                    setState(() => line.foldRange!.isFolded = !line.foldRange!.isFolded);
                  },
                  child: Icon(
                    !line.foldRange!.isFolded ? widget.gutterStyle.unfoldedIcon : widget.gutterStyle.foldedIcon,
                    color: !line.foldRange!.isFolded ? 
                      widget.gutterStyle.unfoldedIconColor : widget.gutterStyle.foldedIconColor,
                    size: widget.gutterStyle.foldingIconSize ?? 
                      (widget.gutterStyle.lineNumberStyle?.fontSize ?? Shared().textStyle?.fontSize ?? 14) * 0.9,
                  ),
                ) : SizedBox.shrink()
              );
            }).toList(),
          );
        }
      ),
    );
  }
}

class GutterItem extends StatelessWidget {
  final Widget leftItem;
  final Widget rightItem;
  final int linNumber;
  final TextStyle? lineNumberStyle;
  final VoidCallback? onTap;
  const GutterItem(
    this.linNumber,{
      super.key, 
      this.lineNumberStyle,
      this.leftItem = const SizedBox.expand(),
      this.rightItem = const SizedBox.expand(),
      this.onTap
    }
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: leftItem),
        GestureDetector(
          onTap: onTap,
          child: Text(
            linNumber.toString(), 
            style: ((){
              if(lineNumberStyle != null) {
                return lineNumberStyle!.copyWith(
                  color: lineNumberStyle?.color ?? Shared().theme['root']?.color,
                  height: 1.5,
                );
              } else if(Shared().textStyle != null) {
                return Shared().textStyle!.copyWith(
                  color: Shared().textStyle?.color ?? Shared().theme['root']?.color,
                  height: 1.5,
                );
              } else {
                return TextStyle(
                  color: Shared().theme.isNotEmpty ? Shared().theme['root']?.color : Colors.white,
                  height: 1.5,
                );
              }
            })(),
          ),
        ),
        Expanded(child: rightItem),
      ],
    );
  }
}

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

  FoldRange(
    this.startLine,
    this.endLine,{this.isFolded = false});
}

void _getFoldRanges(String code, ValueNotifier<List<LineState>> lineStates) {
  final List<String> lines = code.split('\n');
  final lineStateCopy = lineStates.value.map((e) => LineState(
    lineNumber: e.lineNumber,
    hasBreakpoint: e.hasBreakpoint,
  )).toList();
  Map<String, List<int>> stacks = {"{": [], "[" : [], "(" : [], "<":  []};
  const matchingBrackets = {"{": "}", "[": "]", "(": ")", "<": ">"};
  for(final openBracket in matchingBrackets.keys){
    final closeBracket = matchingBrackets[openBracket]!;
    for(int i = 0; i < lines.length; i++){
      if(lines[i].contains(openBracket)){
        stacks[openBracket]!.add(i);
      }
      if(lines[i].contains(closeBracket)){
        if(stacks[openBracket]!.isNotEmpty){
          int start = stacks[openBracket]!.removeLast();
          if(i > start + 1 && i + 1 <= lineStateCopy.length){ {
            bool previouslyFolded = lineStates.value[start].foldRange?.isFolded ?? false;
            lineStateCopy[start] = LineState(
              lineNumber: lineStateCopy[start].lineNumber,
              hasBreakpoint: lineStateCopy[start].hasBreakpoint,
            )..foldRange = FoldRange(start + 1, i + 1, isFolded: previouslyFolded);
          }
        }
      }
     }
    }
  }
  lineStates.value = lineStateCopy;
}