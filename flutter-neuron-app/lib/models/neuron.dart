import 'dart:math' as math;

/// ニューロン（単一ユニット）の実装。
///
/// ニューロンは入力重み（weights）とバイアス（bias）を持ち、
/// シグモイド活性化関数を用いて出力を生成します。
class Neuron {
  /// ニューロンの入力重みベクトル
  List<double> weights;

  /// ニューロンのバイアス
  double bias;

  /// コンストラクタ。
  /// [inputSize] は入力次元数、[initScale] は初期重み/バイアスのスケール（ランダム初期化幅）。
  Neuron(int inputSize, {double initScale = 0.1})
      : weights = List.generate(
            inputSize, (_) => (math.Random().nextDouble() * 2 - 1) * initScale),
        bias = (math.Random().nextDouble() * 2 - 1) * initScale;

  /// シグモイド関数
  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  /// シグモイド関数の微分。
  /// [output] はシグモイド関数の出力値 y であり、y * (1 - y) を計算します。
  double sigmoidDerivative(double output) {
    return output * (1.0 - output);
  }

  /// 入力 [input] を受け取り、ニューロンの活性化出力（0..1）を返す。
  double activate(List<double> input) {
    double s = 0.0;
    for (var i = 0; i < weights.length && i < input.length; i++) {
      s += weights[i] * input[i];
    }
    s += bias;
    return _sigmoid(s);
  }

  /// 誤差（デルタ）と学習率に基づき、重みとバイアスを更新する。
  ///
  /// このメソッドはバックプロパゲーションの一部として `LocalModel` から呼び出されます。
  void updateWeights(List<double> input, double delta, double lr) {
    for (var i = 0; i < weights.length && i < input.length; i++) {
      // 重みの更新: 学習率 * デルタ * 対応する入力
      weights[i] -= lr * delta * input[i];
    }
    // バイアスの更新: 学習率 * デルタ
    bias -= lr * delta;
  }

  /// シリアライズ: JSON 互換の Map を返す
  Map<String, dynamic> toJson() => {
        'weights': weights,
        'bias': bias,
      };

  /// デシリアライズ: JSON 互換 Map から復元するコンストラクタ
  Neuron.fromJson(Map<String, dynamic> j)
      : weights = List<double>.from(j['weights'] as List<dynamic>),
        bias = (j['bias'] as num).toDouble();
}
