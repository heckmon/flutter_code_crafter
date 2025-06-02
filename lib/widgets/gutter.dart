import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_code_crafter/code_crafter/code_crafter_controller.dart';
import 'package:flutter_code_crafter/utils/shared.dart';


class Gutter extends StatefulWidget {
  final double gutterRightMargin, gutterLeftMargin;
  final double? gutterWidth; 
  const Gutter({
    super.key,
    this.gutterWidth,
    this.gutterRightMargin = 10,
    this.gutterLeftMargin = 10,
  });

  @override
  State<Gutter> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  final CodeCrafterController _controller = Shared().controller;
  TextPainter _textPainter = TextPainter();
  int lineNumber = 0;
  double? _gutterWidth;

  @override
  void initState() {
    _controller.addListener((){
      _textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: _controller.text,
        )
      )..layout();
      if(lineNumber != _textPainter.computeLineMetrics().length){
        setState(() => lineNumber = _textPainter.computeLineMetrics().length);
      }
      int digitCount = max(3, lineNumber.toString().length);
      TextPainter gutterPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: List.filled(digitCount, "8").join(),
          style: Shared().textStyle?.copyWith(height: 1.5) ?? TextStyle(fontSize: 17, height: 1.5)
        )
      )..layout();

      _gutterWidth = widget.gutterWidth ?? gutterPainter.width * 2;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _gutterWidth,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: widget.gutterLeftMargin, right: widget.gutterRightMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(lineNumber, (index) => GutterItem(index + 1)),
          ),
        ),
      ),
    );
  }
}

class GutterItem extends StatelessWidget {
  final dynamic leftItem;
  final dynamic rightItem;

  final int linNumber;
  const GutterItem(
    this.linNumber,{
      super.key, 
      this.leftItem = const SizedBox(),
      this.rightItem = const SizedBox()
    }
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leftItem,
        Text(
          linNumber.toString(), 
          style: Shared().textStyle?.copyWith(color: Shared().theme['root']?.color, height: 1.5) ?? 
              TextStyle(color: Shared().theme.isNotEmpty ? Shared().theme['root']?.color : Colors.white, fontSize: 17, height: 1.5)
        ),
        rightItem,
      ],
    );
  }
}
