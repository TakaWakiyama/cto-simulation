/// 社員の職種
enum EmployeeType {
  engineer('エンジニア'),
  sales('営業'),
  marketer('マーケター'),
  backOffice('バックオフィス'),
  hr('人事');

  const EmployeeType(this.label);
  final String label;

  bool get isEngineer => this == EmployeeType.engineer;
}
