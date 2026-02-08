import 'package:flutter/foundation.dart';

enum ProjectType {
  corporateSite('コーポレートサイト'),
  ecSite('ECサイト'),
  webApp('Webアプリ'),
  mobileApp('モバイルアプリ'),
  systemIntegration('基幹システム'),
  api('API開発'),
  aiProject('AI/ML案件');

  const ProjectType(this.label);
  final String label;
}

enum ProjectStatus {
  available('募集中'),
  inProgress('開発中'),
  completed('完了'),
  failed('失敗'),
  overdue('納期超過');

  const ProjectStatus(this.label);
  final String label;
}

@immutable
class ContractProject {
  const ContractProject({
    required this.id,
    required this.name,
    required this.type,
    required this.clientName,
    required this.reward,
    required this.requiredSkill,
    required this.totalWork,
    required this.deadline,
    this.currentWork = 0,
    this.status = ProjectStatus.available,
    this.startTurn,
    this.qualityScore = 50,
    this.assignedEmployeeIds = const [],
  });

  final String id;
  final String name;
  final ProjectType type;
  final String clientName;
  final int reward; // 報酬（万円）
  final int requiredSkill; // 必要スキルレベル 1-100
  final int totalWork; // 必要工数
  final int deadline; // 納期（ターン数）
  final int currentWork; // 現在の進捗工数
  final ProjectStatus status;
  final int? startTurn;
  final int qualityScore; // 品質スコア 0-100
  final List<String> assignedEmployeeIds;

  double get progress => totalWork > 0 ? currentWork / totalWork : 0.0;
  bool get isCompleted => currentWork >= totalWork;

  int remainingTurns(int currentTurn) {
    if (startTurn == null) return deadline;
    return deadline - (currentTurn - startTurn!);
  }

  bool isOverdue(int currentTurn) => remainingTurns(currentTurn) < 0;

  ContractProject copyWith({
    String? id,
    String? name,
    ProjectType? type,
    String? clientName,
    int? reward,
    int? requiredSkill,
    int? totalWork,
    int? deadline,
    int? currentWork,
    ProjectStatus? status,
    int? Function()? startTurn,
    int? qualityScore,
    List<String>? assignedEmployeeIds,
  }) {
    return ContractProject(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      clientName: clientName ?? this.clientName,
      reward: reward ?? this.reward,
      requiredSkill: requiredSkill ?? this.requiredSkill,
      totalWork: totalWork ?? this.totalWork,
      deadline: deadline ?? this.deadline,
      currentWork: currentWork ?? this.currentWork,
      status: status ?? this.status,
      startTurn: startTurn != null ? startTurn() : this.startTurn,
      qualityScore: qualityScore ?? this.qualityScore,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'clientName': clientName,
        'reward': reward,
        'requiredSkill': requiredSkill,
        'totalWork': totalWork,
        'deadline': deadline,
        'currentWork': currentWork,
        'status': status.name,
        'startTurn': startTurn,
        'qualityScore': qualityScore,
        'assignedEmployeeIds': assignedEmployeeIds,
      };

  factory ContractProject.fromJson(Map<String, dynamic> json) =>
      ContractProject(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ProjectType.values.byName(json['type'] as String),
        clientName: json['clientName'] as String,
        reward: json['reward'] as int,
        requiredSkill: json['requiredSkill'] as int,
        totalWork: json['totalWork'] as int,
        deadline: json['deadline'] as int,
        currentWork: json['currentWork'] as int? ?? 0,
        status: ProjectStatus.values
            .byName(json['status'] as String? ?? 'available'),
        startTurn: json['startTurn'] as int?,
        qualityScore: json['qualityScore'] as int? ?? 50,
        assignedEmployeeIds:
            (json['assignedEmployeeIds'] as List<dynamic>?)
                    ?.cast<String>() ??
                const [],
      );
}
