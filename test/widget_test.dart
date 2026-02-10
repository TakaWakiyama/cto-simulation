import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/models/employee.dart';
import 'package:cto_simulator/core/models/employee_type.dart';
import 'package:cto_simulator/core/models/game_config.dart';
import 'package:cto_simulator/core/turn_engine.dart';
import 'package:cto_simulator/core/economy_engine.dart';
import 'package:cto_simulator/ui/widgets/employee_card.dart';

void main() {
  group('GameState', () {
    test('initial state has correct defaults', () {
      const config = GameConfig();
      final state = GameState.initial(config);

      expect(state.money, 600);
      expect(state.trust, 30);
      expect(state.ap, 3);
      expect(state.currentTurn, 1);
      expect(state.employees, isEmpty);
      expect(state.servers, isEmpty);
      expect(state.isGameOver, false);
    });
  });

  group('TurnEngine', () {
    test('initializeGame sets up initial state', () {
      const config = GameConfig();
      final initial = GameState.initial(config);
      final state = TurnEngine.initializeGame(initial);

      expect(state.employees.length, 2);
      expect(state.office, isNotNull);
      expect(state.technologies, isNotEmpty);
      expect(state.contractProjects, isNotEmpty);
      expect(state.turnLog, isNotEmpty);
    });

    test('processTurnEnd advances turn', () {
      const config = GameConfig();
      final initial = GameState.initial(config);
      final state = TurnEngine.initializeGame(initial);
      final nextState = TurnEngine.processTurnEnd(state);

      expect(nextState.currentTurn, state.currentTurn + 1);
      expect(nextState.ap, config.apPerTurn);
    });
  });

  group('EconomyEngine', () {
    test('game over when cash reaches 0', () {
      const config = GameConfig();
      final state = GameState.initial(config).copyWith(money: 0);
      final result = EconomyEngine.checkGameOver(state);

      expect(result.isGameOver, true);
    });

    test('game over when trust reaches 0', () {
      const config = GameConfig();
      final state = GameState.initial(config).copyWith(trust: 0);
      final result = EconomyEngine.checkGameOver(state);

      expect(result.isGameOver, true);
    });

    test('repayDebt reduces money and debt', () {
      const config = GameConfig();
      final state = GameState.initial(config).copyWith(money: 100, debt: 80);
      final result = EconomyEngine.repayDebt(state, 30);

      expect(result.money, 70);
      expect(result.debt, 50);
    });

    test('repayDebt caps amount to remaining debt', () {
      const config = GameConfig();
      final state = GameState.initial(config).copyWith(money: 100, debt: 20);
      final result = EconomyEngine.repayDebt(state, 50);

      expect(result.money, 80);
      expect(result.debt, 0);
    });
  });

  group('EmployeeCard', () {
    testWidgets('staff shows staff type label instead of engineer specialty', (
      tester,
    ) async {
      const marketer = Employee(
        id: 'staff_1',
        name: 'マーケ担当',
        role: EmployeeRole.mid,
        specialty: EmployeeSpecialty.fullstack,
        salary: 30,
        type: EmployeeType.marketer,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmployeeCard(employee: marketer, compact: true)),
        ),
      );

      expect(find.text('マーケター'), findsOneWidget);
      expect(find.textContaining('フルスタック'), findsNothing);
    });
  });
}
