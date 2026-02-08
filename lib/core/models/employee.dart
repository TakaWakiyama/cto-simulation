import 'package:flutter/foundation.dart';

import 'employee_type.dart';

enum EmployeeRole {
  junior('ジュニアエンジニア', 1),
  mid('ミドルエンジニア', 2),
  senior('シニアエンジニア', 3),
  lead('テックリード', 4),
  architect('アーキテクト', 5);

  const EmployeeRole(this.label, this.skillLevel);
  final String label;
  final int skillLevel;
}

enum EmployeeSpecialty {
  frontend('フロントエンド'),
  backend('バックエンド'),
  infra('インフラ'),
  mobile('モバイル'),
  fullstack('フルスタック');

  const EmployeeSpecialty(this.label);
  final String label;
}

@immutable
class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.specialty,
    required this.salary,
    this.type = EmployeeType.engineer,
    this.skill = 50,
    this.fatigue = 0,
    this.happiness = 70,
    this.loyalty = 50,
    this.assignedProjectId,
  });

  final String id;
  final String name;
  final EmployeeRole role;
  final EmployeeSpecialty specialty;
  final int salary; // 月給（万円）
  final EmployeeType type;
  final int skill; // スキル 0-100
  final int fatigue; // 疲労度 0-100
  final int happiness; // 幸福度 0-100
  final int loyalty; // 忠誠度 0-100
  final String? assignedProjectId;

  bool get isEngineer => type == EmployeeType.engineer;

  /// 生産力 = スキル × (1 - 疲労/200) × ロール補正
  double get productivity {
    final fatigueModifier = 1.0 - (fatigue / 200.0);
    return skill * fatigueModifier * (role.skillLevel * 0.3 + 0.4);
  }

  /// 退職リスク（0.0〜1.0）
  double get quitRisk {
    if (happiness > 60 && fatigue < 50) return 0.0;
    final unhappiness = (100 - happiness) / 100.0;
    final exhaustion = fatigue / 100.0;
    final disloyalty = (100 - loyalty) / 100.0;
    return (unhappiness * 0.4 + exhaustion * 0.3 + disloyalty * 0.3)
        .clamp(0.0, 1.0);
  }

  bool get isAssigned => assignedProjectId != null;

  Employee copyWith({
    String? id,
    String? name,
    EmployeeRole? role,
    EmployeeSpecialty? specialty,
    int? salary,
    EmployeeType? type,
    int? skill,
    int? fatigue,
    int? happiness,
    int? loyalty,
    String? Function()? assignedProjectId,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      specialty: specialty ?? this.specialty,
      salary: salary ?? this.salary,
      type: type ?? this.type,
      skill: skill ?? this.skill,
      fatigue: fatigue ?? this.fatigue,
      happiness: happiness ?? this.happiness,
      loyalty: loyalty ?? this.loyalty,
      assignedProjectId: assignedProjectId != null
          ? assignedProjectId()
          : this.assignedProjectId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'specialty': specialty.name,
        'salary': salary,
        'type': type.name,
        'skill': skill,
        'fatigue': fatigue,
        'happiness': happiness,
        'loyalty': loyalty,
        'assignedProjectId': assignedProjectId,
      };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        name: json['name'] as String,
        role: EmployeeRole.values.byName(json['role'] as String),
        specialty:
            EmployeeSpecialty.values.byName(json['specialty'] as String),
        salary: json['salary'] as int,
        type: json['type'] != null
            ? EmployeeType.values.byName(json['type'] as String)
            : EmployeeType.engineer,
        skill: json['skill'] as int? ?? 50,
        fatigue: json['fatigue'] as int? ?? 0,
        happiness: json['happiness'] as int? ?? 70,
        loyalty: json['loyalty'] as int? ?? 50,
        assignedProjectId: json['assignedProjectId'] as String?,
      );
}
