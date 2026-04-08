import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_pulse_app/screens/home/home_screen.dart';

// ============================================================
// HomeScreen 위젯 테스트 — mock Provider로 화면 렌더링을 검증한다
// ============================================================

void main() {
  group('HomeScreen 위젯 테스트', () {
    Widget buildTestWidget() {
      return ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const HomeScreen(),
        ),
      );
    }

    testWidgets('홈 대시보드 타이틀이 렌더링된다', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      // 비동기 데이터 로딩 대기
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('홈 대시보드'), findsOneWidget);
    });

    testWidgets('다음 실행 시간이 표시된다', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('다음 실행'), findsOneWidget);
    });

    testWidgets('새로고침 버튼이 존재한다', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}
