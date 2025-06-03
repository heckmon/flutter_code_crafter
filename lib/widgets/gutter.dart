import 'dart:math';
import 'package:flutter_code_crafter/code_crafter/code_crafter_controller.dart';
import 'package:flutter_code_crafter/utils/shared.dart';
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
    _lineStates =  _lineStates = ValueNotifier(List.generate(lineNumber, (index) => LineState(lineNumber: index + 1)));
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
                    gutterStyle: widget.gutterStyle.lineNumberStyle,
                    leftItem: widget.enableBreakPoints ? GestureDetector(
                      onTap: () {
                        final index = line.lineNumber - 1;
                        final updated = List<LineState>.from(_lineStates.value);
                        updated[index] = LineState(
                          lineNumber: updated[index].lineNumber,
                          hasBreakpoint: !updated[index].hasBreakpoint,
                          isFolded: updated[index].isFolded,
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
  final TextStyle? gutterStyle;
  const GutterItem(
    this.linNumber,{
      super.key, 
      this.gutterStyle,
      this.leftItem = const SizedBox(),
      this.rightItem = const SizedBox()
    }
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        leftItem,
        Text(
          linNumber.toString(), 
          style: ((){
            if(gutterStyle != null) {
              return gutterStyle!.copyWith(
                color: gutterStyle?.color ?? Shared().theme['root']?.color,
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
  bool hasBreakpoint;
  bool isFolded;

  LineState({
    required this.lineNumber,
    this.hasBreakpoint = false,
    this.isFolded = false,
  });
}

class GutterStyle{
  final TextStyle? lineNumberStyle;
  final Color breakpointColor, unfilledBreakpointColor;
  final Color? dividerColor;
  final double? breakpointSize, gutterWidth;
  final double gutterRightMargin, gutterLeftMargin;
  final IconData breakpointIcon, unfilledBreakpointIcon;
  GutterStyle({
    this.lineNumberStyle,
    this.dividerColor,
    this.gutterWidth,
    this.gutterRightMargin = 10,
    this.gutterLeftMargin = 10,
    this.breakpointIcon = Icons.circle,
    this.unfilledBreakpointIcon = Icons.circle_outlined,
    this.breakpointSize,
    this.breakpointColor = Colors.red,
    this.unfilledBreakpointColor = Colors.transparent
  });
}