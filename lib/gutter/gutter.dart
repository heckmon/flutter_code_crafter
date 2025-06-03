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
          getFoldRanges(_controller.text, _lineStates);
        });
      }
      int digitCount = max(3, lineNumber.toString().length);
      TextPainter gutterPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: List.filled(digitCount, "8").join(),
          style: Shared().textStyle?.copyWith(height: 1.5) ?? TextStyle(height: 1.5)
        )
      )..layout();

      _gutterWidth = widget.gutterStyle.gutterWidth ?? gutterPainter.width * 2;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _gutterWidth,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: widget.gutterStyle.gutterLeftMargin, right: widget.gutterStyle.gutterRightMargin),
          child: ValueListenableBuilder<List<LineState>>(
            valueListenable: _lineStates,
            builder: (context, lines, _) {
              return Column(
                children: lines.map((line){
                  return GutterItem(
                    lineNumberAlignment: widget.gutterStyle.lineNumberAlignment,
                    lineNumberStyle: widget.gutterStyle.lineNumberStyle,
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
                      child: Icon(!line.foldRange!.isFolded ? Icons.keyboard_arrow_down_outlined : Icons.chevron_right_outlined),
                    ) : SizedBox.shrink()
                  );
                }).toList(),
              );
            }
          ),
        ),
      ),
    );
  }
}

class GutterItem extends StatelessWidget {
  final Widget leftItem;
  final Widget rightItem;
  final int linNumber;
  final TextStyle? lineNumberStyle;
  final LineNumberAlignment lineNumberAlignment;
  const GutterItem(
    this.linNumber,{
      super.key, 
      required this.lineNumberAlignment,
      this.lineNumberStyle,
      this.leftItem = const SizedBox(),
      this.rightItem = const SizedBox()
    }
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: ((){
        switch(lineNumberAlignment) {
          case LineNumberAlignment.center:
            return MainAxisAlignment.spaceEvenly;
          case LineNumberAlignment.left:
            return MainAxisAlignment.start;
          case LineNumberAlignment.right:
            return MainAxisAlignment.end;
        }
      })(),
      children: [
        leftItem,
        Text(
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
        rightItem,
      ],
    );
  }
}

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

  FoldRange(
    this.startLine,
    this.endLine,{this.isFolded = false});
}

void getFoldRanges(String code, ValueNotifier<List<LineState>> lineStates) {
  final List<String> lines = code.split('\n');
  final lineStateCopy = List<LineState>.from(lineStates.value);
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
            lineStateCopy[start] = LineState(
              lineNumber: lineStateCopy[start].lineNumber,
              hasBreakpoint: lineStateCopy[start].hasBreakpoint
            )..foldRange = FoldRange(start + 1, i + 1);
          }
        }
      }
     }
    }
  }
  lineStates.value = lineStateCopy;
}