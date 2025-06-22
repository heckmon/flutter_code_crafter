A powerful and feature-rich code editor for flutter, designed to bring a seamless and efficient coding experience 


> **Note:** This package is originally developed as part of an Android IDE app that I'm currently working on, so it's optimized for mobile use. PC specific features like extra keyboard shortcuts aren't included by default. If you'd like to add support for those, feel free to open a pull request. I'm currently tied up with college and academics, contributions are welcome!

[![pub package](https://img.shields.io/pub/v/flutter_code_crafter.svg?cacheSeconds=60)](https://pub.dev/packages/flutter_code_crafter)
![GitHub license](https://img.shields.io/github/license/heckmon/flutter_code_crafter.svg)
![GitHub stars](https://img.shields.io/github/stars/heckmon/flutter_code_crafter.svg?style=social&label=Star&cacheSeconds=60)
<a href="https://www.buymeacoffee.com/bames_jond">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="100" height="30">  </a>

## Features

- Syntax highlighting ([available languages](https://github.com/git-touch/highlight.dart/tree/master/highlight/lib/languages))
- Multiple themes ([available themes](https://github.com/git-touch/highlight.dart/tree/master/flutter_highlight/lib/themes))
- Code folding
- AI code completion
- Built-in universal LSP client (Suggestions, diagnostics, etc.)
- Vertical ruler lines (Indentation guides lines similar to VSCode)
- Code formatting (Auto indentation, line   wrapping, etc.)
<br>

<p align="left">
  <img src="https://files.catbox.moe/ohyfpu.gif" alt="Syntax Highlighting" width="425" height="415"><br>
  <sub>AI Code completion and LSP suggestion</sub>
</p>

<p align="left">
  <img src="https://files.catbox.moe/kic1bb.gif" alt="Code Folding" width="425" height="415"><br>
  <sub>Code folding and breakpoints</sub>
</p>

<p align="left">
  <img src="https://files.catbox.moe/4skc39.gif" alt="AI Completion" width="425" height="415"><br>
  <sub>LSP hover using pyright LSP server</sub>
</p>

<p align="left">
  <img src="https://files.catbox.moe/y5kzcr.gif" alt="LSP Client" width="425" height="425"><br>
  <sub>Bracket matching and auto indentation<br>error highlight using clangd LSP server</sub>
</p>

<br>

> #### Note : The above features works on all supported languages, I just used python for the demo.<br> You can use any language with corresponding LSP server to get hover details and suggestions similar to VScode.

## Usage

### Basic usage
Plug and play with `CodeCrafter` widget. Import a langauge from the [highlight](https://pub.dev/packages/highlight) package and theme from the [flutter_highlight](https://pub.dev/packages/flutter_highlight) package, and you're good to go!

```dart
import 'package:flutter/material.dart';
import 'package:flutter_code_crafter/code_crafter.dart';
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
 - To Setup AI code completion, follow this documentation: [AI Code Completion](https://github.com/heckmon/flutter_code_crafter/blob/main/docs/AICompletion.md)
 - To Setup LSP client, follow this documentation: [LSP Client](https://github.com/heckmon/flutter_code_crafter/blob/main/docs/LSPClient.md)


## Additional information

This package contains `dart:io` import, so web supported may be limited. Also there is an issue with tab key when `wrapLines` property is set to false. This is a known issue with the underlying text editing library and will be fixed in future releases.

Contributions are welcome! If you find any bugs or have any feature requests, please open an issue on the [GitHub repository](https://github.com/heckmon/fluter_code_crafter).
