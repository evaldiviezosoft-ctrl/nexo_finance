import '../../../core/firebase/firestore_converters.dart';

enum CategoryType { expense, income }

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.iconCodePoint = 0xe57f,
    this.colorValue = 0xffff1744,
    this.order = 0,
    this.active = true,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final String? parentId;
  final int iconCodePoint;
  final int colorValue;
  final int order;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  factory FinanceCategory.fromMap(Map<String, Object?> map) => FinanceCategory(
    id: map['id']! as String,
    userId: map['userId']! as String,
    name: map['name']! as String,
    type: CategoryType.values.byName(map['type']! as String),
    parentId: map['parentId'] as String?,
    iconCodePoint: map['iconCodePoint'] as int? ?? 0xe57f,
    colorValue: map['colorValue'] as int? ?? 0xffff1744,
    order: map['order'] as int? ?? 0,
    active: map['active'] as bool? ?? true,
    createdAt: dateTimeFromFirestore(map['createdAt']),
    updatedAt: dateTimeFromFirestore(map['updatedAt']),
    version: map['version'] as int? ?? 1,
    deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
  );
}
