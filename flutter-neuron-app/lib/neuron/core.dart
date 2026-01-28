// Neuron core: minimal matrix ops and layer/model skeletons.
// コメント: このファイルは最小プロトタイプ用。可読性優先で実装。

class Matrix {
  // 行列の乗算: a (m x n) * b (n x p) => (m x p)
  static List<List<double>> multiply(
      List<List<double>> a, List<List<double>> b) {
    final m = a.length;
    final n = a[0].length;
    final p = b[0].length;
    var out = List.generate(m, (_) => List.filled(p, 0.0));
    for (var i = 0; i < m; i++) {
      for (var k = 0; k < n; k++) {
        for (var j = 0; j < p; j++) {
          out[i][j] += a[i][k] * b[k][j];
        }
      }
    }
    return out;
  }

  // ベクトル（列）との乗算: weights (out x in) * input (in) => output (out)
  static List<double> multiplyVec(List<List<double>> a, List<double> v) {
    final m = a.length;
    final n = a[0].length;
    var out = List.filled(m, 0.0);
    for (var i = 0; i < m; i++) {
      var sum = 0.0;
      for (var j = 0; j < n; j++) {
        sum += a[i][j] * v[j];
      }
      out[i] = sum;
    }
    return out;
  }

  // 要素ごとの加算（ベクトル）
  static List<double> addVec(List<double> a, List<double> b) {
    final n = a.length;
    var out = List.filled(n, 0.0);
    for (var i = 0; i < n; i++) out[i] = a[i] + b[i];
    return out;
  }
}

double relu(double x) => x > 0 ? x : 0.0;

class DenseLayer {
  final int inputSize;
  final int outputSize;
  List<List<double>> weights; // shape: outputSize x inputSize
  List<double> bias; // shape: outputSize

  // コメント: 最小実装でランダム初期化
  DenseLayer(this.inputSize, this.outputSize)
      : weights = List.generate(
            outputSize, (_) => List.generate(inputSize, (_) => _randInit())),
        bias = List.generate(outputSize, (_) => 0.0);

  // フォワードのみ実装（シンプルなReLU活性化）
  List<double> forward(List<double> input) {
    var z = Matrix.multiplyVec(weights, input);
    z = Matrix.addVec(z, bias);
    for (var i = 0; i < z.length; i++) z[i] = relu(z[i]);
    return z;
  }

  Map<String, dynamic> toJson() => {
        'inputSize': inputSize,
        'outputSize': outputSize,
        'weights': weights,
        'bias': bias,
      };

  static DenseLayer fromJson(Map<String, dynamic> m) {
    final layer = DenseLayer(m['inputSize'] as int, m['outputSize'] as int);
    // 型の確認と代入（簡易）
    final w = (m['weights'] as List)
        .map((r) => (r as List).map((e) => (e as num).toDouble()).toList())
        .toList();
    layer.weights = List<List<double>>.from(w);
    layer.bias = (m['bias'] as List).map((e) => (e as num).toDouble()).toList();
    return layer;
  }
}

class NeuronModel {
  List<DenseLayer> layers;

  NeuronModel({List<DenseLayer>? layers}) : layers = layers ?? [];

  // 単純な順伝播
  List<double> forward(List<double> input) {
    var x = input;
    for (var layer in layers) {
      x = layer.forward(x);
    }
    return x;
  }

  // シリアライズ
  Map<String, dynamic> toJson() => {
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  // 更新を適用する（updateは簡易で重み/バiasの置換を想定）
  void applyUpdate(Map<String, dynamic> update) {
    // コメント: ここでは完全置換を想定する。差分マージは後で実装。
    if (update.containsKey('layers')) {
      final ls = update['layers'] as List;
      layers = ls
          .map((e) => DenseLayer.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ユーティリティ: ランダムに単層モデルを作る（テスト用）
  static NeuronModel random(int inputSize, int hiddenSize, int outputSize) {
    return NeuronModel(layers: [
      DenseLayer(inputSize, hiddenSize),
      DenseLayer(hiddenSize, outputSize)
    ]);
  }
}

double _randInit() {
  // 小さなランダム初期値
  return (DateTime.now().microsecondsSinceEpoch % 1000) / 100000.0;
}
