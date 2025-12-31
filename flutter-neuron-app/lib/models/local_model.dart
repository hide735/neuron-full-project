import 'neuron.dart';

/// ローカルに保持されるニューロンモデルの集合を表します。
///
/// このモデルは現在、単一の全結合層として機能します。
class LocalModel {
  /// ニューロンのリスト
  List<Neuron> neurons;

  /// 短期記憶: 直前の会話の入力ベクトルを保持する
  /// この状態はモデルの永続化の対象外
  List<double>? _lastInput;
  List<double>? get lastInput => _lastInput;

  /// 短期記憶を更新する
  void updateLastInput(List<double> input) {
    _lastInput = input;
  }

  /// [inputSize] は各ニューロンの入力次元、[neuronCount] はニューロン数
  LocalModel({int inputSize = 16, int neuronCount = 8})
      : neurons = List.generate(neuronCount, (_) => Neuron(inputSize));

  /// 入力ベクトル [input] を与えて、各ニューロンの出力ベクトルを返す。
  List<double> forward(List<double> input) {
    return neurons.map((n) => n.activate(input)).toList();
  }

  /// モデルの学習（トレーニング）を実行します。
  ///
  /// このメソッドは、指定された入力と目標（ターゲット）に基づき、
  /// バックプロパゲーション（誤差逆伝播法）を用いてニューロンの重みを更新します。
  /// [input] は学習データ、[target] は正解ラベルのベクトル、[lr] は学習率です。
  ///
  /// 現在の実装は、出力層が1層のみの単純なモデルを想定しています。
  void train(List<double> input, List<double> target, double lr) {
    // 1. まず、現在の入力でモデルの出力を計算する（順伝播）
    final outputs = forward(input);

    // 2. 各出力ニューロンについて、誤差を計算し、重みを更新する
    for (var i = 0; i < neurons.length; i++) {
      // ターゲット（正解）と実際の出力との誤差を計算
      final error = target[i] - outputs[i];

      // 誤差と活性化関数の微分を使い、このニューロンのデルタ（勾配の要素）を計算
      // デルタ = 誤差 * シグモイドの微分(出力)
      final delta = error * neurons[i].sigmoidDerivative(outputs[i]);

      // 計算したデルタを使い、ニューロンの重みを更新
      neurons[i].updateWeights(input, delta, lr);
    }
  }

  /// シリアライズ
  Map<String, dynamic> toJson() => {
        'neurons': neurons.map((n) => n.toJson()).toList(),
      };

  /// デシリアライズ
  LocalModel.fromJson(Map<String, dynamic> j)
      : neurons = (j['neurons'] as List<dynamic>)
            .map((e) => Neuron.fromJson(e as Map<String, dynamic>))
            .toList();

  /// 別のモデルと自身のモデルをマージ（平均化）する
  void mergeWith(LocalModel other) {
    if (neurons.length != other.neurons.length) {
      print('❗️ Model merge failed: Neuron count mismatch.');
      return;
    }

    for (int i = 0; i < neurons.length; i++) {
      final myNeuron = neurons[i];
      final otherNeuron = other.neurons[i];

      if (myNeuron.weights.length != otherNeuron.weights.length) {
        print('❗️ Model merge failed: Weight count mismatch at neuron $i.');
        return;
      }

      for (int j = 0; j < myNeuron.weights.length; j++) {
        myNeuron.weights[j] =
            (myNeuron.weights[j] + otherNeuron.weights[j]) / 2.0;
      }
      myNeuron.bias = (myNeuron.bias + otherNeuron.bias) / 2.0;
    }
    print('✅ Models merged successfully.');
  }
}
