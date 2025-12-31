import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/local_kb.dart';

/// 設定画面: 応答の温度（ランダム性）と学習率を調整するUIを提供します。
class SettingsPage extends StatefulWidget {
  /// 初期温度
  final double initialTemperature;

  /// 初期学習率
  final double initialLearningRate;

  /// コンストラクタ
  const SettingsPage(
      {super.key,
      this.initialTemperature = 1.0,
      this.initialLearningRate = 0.01});

  @override
  SettingsPageState createState() => SettingsPageState();
}

/// 設定画面の状態管理
class SettingsPageState extends State<SettingsPage> {
  late double _temperature;
  late double _learningRate;
  final TextEditingController _urlController = TextEditingController();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _temperature = widget.initialTemperature;
    _learningRate = widget.initialLearningRate;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// 設定を保存して前画面に true を返す
  Future<void> _save() async {
    await Storage.saveJson('settings.json', {
      'temperature': _temperature,
      'learning_rate': _learningRate,
    });
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// 指定 URL を LocalKB に取り込む
  Future<void> _importUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _isImporting = true);
    final kb = LocalKB();
    try {
      final id = await kb.fetchAndAddFromUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported to LocalKB (id: $id)')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      await kb.close();
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Response temperature',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _temperature,
              min: 0.1,
              max: 2.0,
              divisions: 19,
              label: _temperature.toStringAsFixed(2),
              onChanged: (v) => setState(() => _temperature = v),
            ),
            const SizedBox(height: 16),
            const Text('Learning rate',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _learningRate,
              min: 0.0001,
              max: 0.1,
              divisions: 1000,
              label: _learningRate.toStringAsPrecision(2),
              onChanged: (v) => setState(() => _learningRate = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(height: 24),
            const Text('Import from URL',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                      hintText: 'https://example.com/article'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isImporting ? null : _importUrl,
                child: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Import'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
