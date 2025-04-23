import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http; // http パッケージをインポート
import 'dart:convert'; // jsonDecode を使用するためにインポート
import 'dart:math'; // minを使用するためにインポート

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'API Demo',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
        textTheme: CupertinoTextThemeData(primaryColor: CupertinoColors.black),
      ),
      home: const MyHomePage(title: 'AI テキスト生成'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller =
      TextEditingController(); // TextFieldコントローラー
  final TextEditingController _apiUrlController =
      TextEditingController(); // APIのURLコントローラー
  String _generatedText = ''; // APIからのレスポンスを保持
  bool _isLoading = false; // ローディング状態
  bool _isCheckingHealth = false; // ヘルスチェックのローディング状態
  String? _errorMessage; // エラーメッセージ
  String? _healthStatus; // ヘルスチェックの結果を保持

  // API のベースURL (末尾のスラッシュなし)
  String _apiBaseUrl = 'https://xxxxxxxxxx';

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = _apiBaseUrl; // 初期値を設定
  }

  // APIのBaseURLを更新する関数
  void _updateApiBaseUrl() {
    if (_apiUrlController.text.isEmpty) {
      setState(() {
        _errorMessage = 'APIのURLを入力してください。';
      });
      return;
    }

    // 末尾のスラッシュを削除
    String newUrl = _apiUrlController.text;
    if (newUrl.endsWith('/')) {
      newUrl = newUrl.substring(0, newUrl.length - 1);
    }

    setState(() {
      _apiBaseUrl = newUrl;
      _healthStatus = null; // ヘルスチェック結果をリセット
      _errorMessage = null;
    });
  }

  // APIリクエストを送信する関数
  Future<void> _sendRequest() async {
    if (_controller.text.isEmpty) {
      setState(() {
        _errorMessage = 'プロンプトを入力してください。';
        _generatedText = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // エラーメッセージをリセット
      _generatedText = ''; // 前回の結果をクリア
      _healthStatus = null; // ヘルスチェック結果もクリア
    });

    final apiUrl = '$_apiBaseUrl/generate'; // ベースURLから生成
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "prompt": _controller.text,
      "max_new_tokens": 1024,
      "do_sample": false,
      "temperature": 0.7,
      "top_p": 0.9,
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(
          utf8.decode(response.bodyBytes),
        ); // UTF-8でデコード
        setState(() {
          _generatedText =
              decodedResponse['generated_text'] ??
              'レスポンスに generated_text がありません。';
          _errorMessage = null;
        });
      } else if (response.statusCode == 422) {
        final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
        // エラー詳細を取得（構造が異なる可能性があるため、より堅牢なパースが必要な場合あり）
        final detail = decodedResponse['detail']?.toString() ?? '不明なバリデーションエラー';
        setState(() {
          _errorMessage = 'Validation Error (${response.statusCode}): $detail';
          _generatedText = '';
        });
      } else {
        setState(() {
          _errorMessage = 'エラーが発生しました: ${response.statusCode}';
          _generatedText = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'リクエスト中にエラーが発生しました: $e';
        _generatedText = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // /health エンドポイントへ GET リクエストを送信する関数
  Future<void> _checkHealth() async {
    setState(() {
      _isCheckingHealth = true;
      _healthStatus = null; // 前回の結果をクリア
      _errorMessage = null; // エラーメッセージをクリア
      _generatedText = ''; // 生成結果もクリア
    });

    final healthUrl = '$_apiBaseUrl/health'; // ベースURLから生成
    // final headers = {'Accept': 'application/json'}; // Acceptヘッダーを指定
    print('リクエスト送信先: $healthUrl'); // URLを確認

    try {
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: {'Accept': 'application/json'}, // Acceptヘッダーを追加
      );

      // デバッグ出力を追加
      print('ステータスコード: ${response.statusCode}');
      print('レスポンスヘッダー: ${response.headers}');

      // レスポンスの中身を表示（長すぎる場合は切り詰める）
      final bodyPreview =
          response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body;
      print('レスポンス本文: $bodyPreview');

      if (response.statusCode == 200) {
        try {
          // レスポンスがHTMLかどうかを簡易チェック
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html')) {
            setState(() {
              _healthStatus = 'エラー: APIがHTMLを返しました。サーバー設定を確認してください。';
              _errorMessage = null;
            });
            return;
          }

          final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
          print('デコード成功: $decodedResponse');

          setState(() {
            // レスポンスから情報を取得して表示
            final status = decodedResponse['status'] ?? 'N/A';
            final model = decodedResponse['model'] ?? 'N/A';
            _healthStatus = 'Status: $status, Model: $model';
            _errorMessage = null;
          });
        } catch (e) {
          print('JSONパースエラー詳細: $e');
          setState(() {
            _healthStatus = 'JSONパースエラー: $e';
            _errorMessage = null;
          });
        }
      } else {
        setState(() {
          _healthStatus = 'ヘルスチェック失敗: ${response.statusCode}';
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('ネットワークエラー詳細: $e');
      setState(() {
        _healthStatus = 'ヘルスチェック中にエラー: $e';
        _errorMessage = null;
      });
    } finally {
      setState(() {
        _isCheckingHealth = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // コントローラーを破棄
    _apiUrlController.dispose(); // APIのURLコントローラーを破棄
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        backgroundColor: CupertinoColors.systemBackground,
        border: const Border(
          bottom: BorderSide(color: CupertinoColors.systemGrey4, width: 0),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // バックエンド設定セクション
              _buildSectionHeader('バックエンド設定'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoTextField(
                      controller: _apiUrlController,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          CupertinoIcons.link,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      placeholder: 'https://example.com',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSubmitted: (_) => _updateApiBaseUrl(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF222222), CupertinoColors.black],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: GestureDetector(
                          onTap: _updateApiBaseUrl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '適用',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_apiBaseUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.info_circle,
                              size: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '現在のAPI URL: $_apiBaseUrl',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // プロンプト入力セクション
              _buildSectionHeader('AIモデルにプロンプトを送信'),
              const SizedBox(height: 6),
              Text(
                'プロンプトを入力して、AIモデルからの応答を得ることができます。',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoTextField(
                      controller: _controller,
                      placeholder: '質問や指示を入力してください',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          CupertinoIcons.text_bubble,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendRequest(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF222222),
                                  CupertinoColors.black,
                                ],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              elevation: 0,
                              child: GestureDetector(
                                onTap:
                                    _isLoading || _isCheckingHealth
                                        ? null
                                        : _sendRequest,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  alignment: Alignment.center,
                                  child:
                                      _isLoading
                                          ? const CupertinoActivityIndicator(
                                            radius: 10,
                                            color: CupertinoColors.white,
                                          )
                                          : const Text(
                                            'テキスト生成',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  CupertinoColors.white,
                                  Color(0xFFF5F5F5),
                                ],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              elevation: 0,
                              child: GestureDetector(
                                onTap:
                                    _isLoading || _isCheckingHealth
                                        ? null
                                        : _checkHealth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: CupertinoColors.black,
                                      width: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  alignment: Alignment.center,
                                  child:
                                      _isCheckingHealth
                                          ? const CupertinoActivityIndicator(
                                            radius: 10,
                                          )
                                          : const Text(
                                            'ヘルスチェック',
                                            style: TextStyle(
                                              color: CupertinoColors.black,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // エラーと状態表示セクション
              if (_errorMessage != null && _controller.text.isNotEmpty ||
                  _healthStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _healthStatus != null &&
                                  _healthStatus!.startsWith('Status: ok')
                              ? CupertinoColors.systemGreen.withOpacity(0.1)
                              : CupertinoColors.systemRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _healthStatus != null &&
                                    _healthStatus!.startsWith('Status: ok')
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null &&
                            _controller.text.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_circle,
                                color: CupertinoColors.systemRed,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: CupertinoColors.systemRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_healthStatus != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _healthStatus!.startsWith('Status: ok')
                                    ? CupertinoIcons.check_mark_circled
                                    : CupertinoIcons.exclamationmark_circle,
                                color:
                                    _healthStatus!.startsWith('Status: ok')
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.systemRed,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _healthStatus!,
                                  style: TextStyle(
                                    color:
                                        _healthStatus!.startsWith('Status: ok')
                                            ? CupertinoColors.systemGreen
                                            : CupertinoColors.systemRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

              // 結果表示セクション
              const SizedBox(height: 24),
              _buildSectionHeader('応答結果'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 300, // 固定高さを設定
                padding: const EdgeInsets.all(16.0),
                child:
                    _generatedText.isNotEmpty
                        ? SingleChildScrollView(
                          child: SelectableText(
                            _generatedText,
                            style: const TextStyle(
                              color: CupertinoColors.black,
                            ),
                          ),
                        )
                        : Center(
                          child: Text(
                            (_isLoading ||
                                    _isCheckingHealth ||
                                    _errorMessage != null ||
                                    _healthStatus != null ||
                                    _controller.text.isEmpty)
                                ? ''
                                : 'ここに回答が表示されます',
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // セクションヘッダーを作成する関数
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.black,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: CupertinoColors.systemGrey4)),
      ],
    );
  }
}
