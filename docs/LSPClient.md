# CodeCrafter LSPClient
CodeCrafter provides a built-in LSP client that allows you to connect to any LSP server and get suggestions, diagnostics, and more. This is useful for advanced code editing features like auto-completion, error checking, and more.

>**Important:**  
If you use LSP, you must provide a valid `filePath` to the `filePath` parameter of the `CodeCrafter` widget. Also The `filePath` provided in both the `CodeCrafter` widget and the `LspConfig` class must be the same. Otherwise, an exception will be thrown.

## Types
#### There are two ways to configure LSP client with code crafter:
1. Using WebSocket (easy and recommended)
2. Using stdio

### 1. Using WebSocket

The class `LspSocketConfig` is used to connect to an LSP server using WebSocket. It takes the following parameters:
- `serverUrl`: The WebSocket URL of the LSP server.
- `filePath`: A filePath is required by the LSP server to provide completions and diagnostics.
- `workspacePath`: The workspace path is the current directory or the parent directory which holds the `filePath` file.
- `languageId`: This is a server specific parameter. eg: `'python'` is the language ID used in pyright language server.

You can easily start any language server using websocket using the  [lsp-ws-proxy](https://github.com/qualified/lsp-ws-proxy) package. For example, to start a pyright language server, you can use the following command:<br>
(On Android, you can use [Termux](https://github.com/termux/termux-app))

```bash
cd /Downloads/lsp-ws-proxy_linux # Navigate to the directory where lsp-ws-proxy is located

./lsp-ws-proxy --listen 5656 -- pyright-langserver --stdio # Start the pyright language server on port 5656
```

#### Example:
create a `LspSocketConfig` object and pass it to the `CodeCrafter` widget.

```dart
final lspConfig = LspSocketConfig(
    filePath: '/home/athul/Projects/lsp/example.py',
    workspacePath: "/home/athul/Projects/lsp",
    languageId: "python",
    serverUrl: "ws://localhost:5656"
),
```
Then pass the `lspConfig` instance to the `CodeCrafter` widget:

```dart
CodeCrafter(
    controller: controller,
    theme: anOldHopeTheme,
    lspConfig: lspConfig, // Pass the LSP config here
),
```

### 2. Using Stdio

Easy to start, no terminal setup or extra package needed, but requires more setup in the code. The `LspStdioConfig.start()` method is used to connect to an LSP server using stdio, which is an asynchronous method, So a `FutureBuilder` is required. It takes the following parameters:
- `executable`: Location of the LSP server executable file.
- `args`: Arguments to pass to the LSP server executable.
- `filePath`: A filePath is required by the LSP server to provide completions and diagnostics.
- `workspacePath`: The workspace path is the current directory or parent directory which holds the `filePath` file.
- `languageId`: This is a server specific parameter. eg: `'python'` is the language ID used in pyright language server.

To get the `executable` path, you can use the `which` command in the terminal. For example, to get the path of the `pyright-langserver`, you can use the following command:

```bash
which pyright-langserver
```

#### Example:
Create an async method to initialize the LSP configuration.
```dart
Future<LspConfig?> _initLsp() async {
    try {
      final config = await LspStdioConfig.start(
        executable: '/home/athul/.nvm/versions/node/v20.19.2/bin/pyright-langserver',
        args: ['--stdio']
        filePath: '/home/athul/Projects/lsp/example.py',
        workspacePath: '/home/athul/Projects/lsp',
        languageId: 'python',
      );
      
      return config;
    } catch (e) {
      debugPrint('LSP Initialization failed: $e');
      return null;
    }
  }
  ```
  Then use a `FutureBuilder` to initialize the LSP configuration and pass it to the `CodeCrafter` widget:
```dart
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: FutureBuilder(
            future: _initLsp(), // Call the async method to get the LSP config
            builder: (context, snapshot) {
              if(snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              return CodeCrafter(
                wrapLines: true,
                editorTheme: anOldHopeTheme,
                controller: controller,
                filePath: '/home/athul/Projects/lsp/example.py',
                textStyle: TextStyle(fontSize: 15, fontFamily: 'monospace'),
                lspConfig: snapshot.data, // Pass the LSP config here
              );
            }
          ),
        ) 
      ),
    );
  }