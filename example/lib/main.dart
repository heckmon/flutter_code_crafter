import 'package:flutter_code_crafter/code_crafter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/an-old-hope.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/languages/python.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final CodeCrafterController controller;
  late final Models model;

  @override
  void initState() {
    controller = CodeCrafterController();
    controller.language = python;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CodeCrafter(
          editorTheme: anOldHopeTheme,
          controller: controller,
          filePath: '/home/athul/Projects/lsp/example.py',
          textStyle: GoogleFonts.notoSansMono(fontSize: 15),
          aiCompletion: AiCompletion(
            enableCompletion: true,
            model: Gemini(apiKey: apiKey),
          ),
          lspConfig: LspSocketConfig(
            filePath: '/home/athul/Projects/lsp/example.py',
            workspacePath: "/home/athul/Projects/lsp",
            languageId: "python",
            serverUrl: "ws://localhost:5656",
          ),
        ),
      ),
    );
  }
}
