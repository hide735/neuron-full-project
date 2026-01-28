import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neuron_app/neuron/core.dart';

void main() {
  group('Matrix ops', () {
    test('multiplyVec simple identity-like', () {
      final weights = [
        [1.0, 0.0],
        [0.0, 1.0]
      ];
      final input = [2.0, 3.0];
      final out = Matrix.multiplyVec(weights, input);
      expect(out, equals([2.0, 3.0]));
    });
  });

  group('DenseLayer / NeuronModel', () {
    test('DenseLayer forward with identity weights', () {
      final layer = DenseLayer(2, 2);
      layer.weights = [
        [1.0, 0.0],
        [0.0, 1.0]
      ];
      layer.bias = [0.0, 0.0];
      final out = layer.forward([2.0, -1.0]);
      // ReLU applied: negative becomes 0
      expect(out, equals([2.0, 0.0]));
    });

    test('NeuronModel forward through two layers', () {
      final l1 = DenseLayer(2, 2);
      l1.weights = [
        [1.0, 0.0],
        [0.0, 1.0]
      ];
      l1.bias = [0.0, 0.0];
      final l2 = DenseLayer(2, 2);
      l2.weights = [
        [1.0, 0.0],
        [0.0, 1.0]
      ];
      l2.bias = [0.0, 0.0];
      final model = NeuronModel(layers: [l1, l2]);
      final out = model.forward([1.0, 2.0]);
      expect(out, equals([1.0, 2.0]));
    });

    test('serialize/deserialize layer roundtrip', () {
      final l = DenseLayer(3, 2);
      l.weights = [
        [0.1, 0.2, 0.3],
        [0.4, 0.5, 0.6]
      ];
      l.bias = [0.0, 0.1];
      final json = l.toJson();
      final l2 = DenseLayer.fromJson(json);
      expect(l2.inputSize, equals(l.inputSize));
      expect(l2.outputSize, equals(l.outputSize));
      expect(l2.bias, equals(l.bias));
    });
  });
}
