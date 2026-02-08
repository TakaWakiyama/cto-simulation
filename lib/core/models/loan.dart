import 'package:flutter/foundation.dart';

/// ローンのサイズ
enum LoanSize {
  small('小口融資', 100, 0.008, 12),
  medium('中口融資', 300, 0.012, 24),
  large('大口融資', 500, 0.018, 36);

  const LoanSize(this.label, this.amount, this.monthlyRate, this.termMonths);
  final String label;
  final int amount; // 万円
  final double monthlyRate; // 月利
  final int termMonths; // 返済期間（ターン）
}

@immutable
class Loan {
  const Loan({
    required this.id,
    required this.size,
    required this.principal,
    required this.remainingPrincipal,
    required this.monthlyRate,
    required this.termMonths,
    required this.remainingMonths,
    required this.startTurn,
  });

  final String id;
  final LoanSize size;
  final int principal; // 元本（万円）
  final int remainingPrincipal; // 残元本（万円）
  final double monthlyRate;
  final int termMonths;
  final int remainingMonths;
  final int startTurn;

  /// 毎月の返済額（元本均等＋利息）
  int get monthlyPayment {
    if (remainingMonths <= 0) return 0;
    final principalPart = (principal / termMonths).ceil();
    final interestPart = (remainingPrincipal * monthlyRate).round();
    return principalPart + interestPart;
  }

  /// 完済済みか
  bool get isPaidOff => remainingPrincipal <= 0;

  /// 一括返済額
  int get earlyRepayAmount => remainingPrincipal;

  factory Loan.create(LoanSize size, int startTurn) => Loan(
        id: 'loan_${DateTime.now().millisecondsSinceEpoch}',
        size: size,
        principal: size.amount,
        remainingPrincipal: size.amount,
        monthlyRate: size.monthlyRate,
        termMonths: size.termMonths,
        remainingMonths: size.termMonths,
        startTurn: startTurn,
      );

  Loan copyWith({
    int? remainingPrincipal,
    int? remainingMonths,
  }) {
    return Loan(
      id: id,
      size: size,
      principal: principal,
      remainingPrincipal: remainingPrincipal ?? this.remainingPrincipal,
      monthlyRate: monthlyRate,
      termMonths: termMonths,
      remainingMonths: remainingMonths ?? this.remainingMonths,
      startTurn: startTurn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'size': size.name,
        'principal': principal,
        'remainingPrincipal': remainingPrincipal,
        'monthlyRate': monthlyRate,
        'termMonths': termMonths,
        'remainingMonths': remainingMonths,
        'startTurn': startTurn,
      };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as String,
        size: LoanSize.values.byName(json['size'] as String),
        principal: json['principal'] as int,
        remainingPrincipal: json['remainingPrincipal'] as int,
        monthlyRate: (json['monthlyRate'] as num).toDouble(),
        termMonths: json['termMonths'] as int,
        remainingMonths: json['remainingMonths'] as int,
        startTurn: json['startTurn'] as int,
      );
}
