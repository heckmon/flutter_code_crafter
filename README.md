A powerful and feature-rich code editor for flutter, designed to bring a seamless and efficient coding experience 


> **Note:** This package is originally developed as part of an Android IDE app that I'm currently working on, so it's optimized for mobile use. PC specific features like extra keyboard shortcuts aren't included by default. If you'd like to add support for those, feel free to open a pull request. I'm currently tied up with college and academics, contributions are welcome!

[![pub package](https://img.shields.io/pub/v/flutter_code_crafter.svg)](https://pub.dev/packages/code_editor)
![GitHub stars](https://img.shields.io/github/stars/heckmon/flutter_code_crafter.svg?style=social&label=Star)

## Features

- Syntax highlighting ([available languages](https://github.com/git-touch/highlight.dart/tree/master/highlight/lib/languages))
- Multiple themes ([available themes](https://github.com/git-touch/highlight.dart/tree/master/flutter_highlight/lib/themes))
- Code folding
- Vertical ruler lines (Indentation guides lines similar to VSCode)
- AI code completion
- Built-in universal LSP client (Suggestions, diagnostics, etc.)
- Code formatting (Auto indentation, line   wrapping, etc.)

## Usage

### Basic usage
Plug and play with `CodeCrafter` widget. Import a langauge from the [highlight](https://pub.dev/packages/highlight) package and theme from the [flutter_highlight](https://pub.dev/packages/flutter_highlight) package, and you're good to go!

```dart
import 'package:flutter/material.dart';
import 'package:code_crafter/code_crafter.dart';
import 'package:flutter_highlight/themes/an-old-hope.dart'; // Import the theme you want to use
import 'package:highlight/languages/python.dart'; // Import the language you want to use

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final CodeCrafterController controller; // Initialize the CodeCrafterController

  @override
  void initState() {
    controller = CodeCrafterController();
    controller.language = python; // Set the language for syntax highlighting
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Code Crafter Example')),
        body: CodeCrafter(
          controller: controller,
          theme: anOldHopeTheme, // Use the imported theme
        ),
      ),
    );
  }
}

```
### Advanced usage
 - To Setup AI code completion, follow this documentation: [AI Code Completion](https://github.com/heckmon/flutter_code_crafter/docs/AICompletion.md)
 - To Setup LSP client, follow this documentation: [LSP Client](https://github.com/heckmon/flutter_code_crafter/docs/LSPClient.md)


## Additional information

This package contains `dart:io` import, so web supported may be limited. Also there is an issue with tab key when `wrapLines` property is set to false. This is a known issue with the underlying text editing library and will be fixed in future releases.

Contributions are welcome! If you find any bugs or have any feature requests, please open an issue on the [GitHub repository](https://github.com/heckmon/fluter_code_crafter).
