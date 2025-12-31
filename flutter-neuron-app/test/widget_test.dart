import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_neuron_app/main.dart';
import 'package:flutter_neuron_app/ui/chat_page.dart';

void main() {
  testWidgets('App shows ChatPage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // ChatPage が表示されていること
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('Sending message displays it in the list',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 入力フィールドに文字列を入力して送信ボタンを押す
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'こんにちは');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // 送信したメッセージがリストに表示される
    expect(find.text('こんにちは'), findsWidgets);
  });
}
