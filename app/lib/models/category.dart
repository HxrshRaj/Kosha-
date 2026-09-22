import 'package:flutter/material.dart';

import 'transaction_type.dart';

class Category {
  final int id;
  final String name;
  final TransactionType type;
  final String color;
  final String icon;
  final double? monthlyBudget;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.monthlyBudget,
  });

  Color get materialColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData get materialIcon => _iconMap[icon] ?? Icons.category;

  static const _iconMap = <String, IconData>{
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'payments': Icons.payments,
    'work': Icons.work,
    'more_horiz': Icons.more_horiz,
    'category': Icons.category,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    name: json['name'] as String,
    type: TransactionType.fromJson(json['type'] as String),
    color: json['color'] as String,
    icon: json['icon'] as String,
    monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toJson(),
    'color': color,
    'icon': icon,
    'monthly_budget': monthlyBudget,
  };
}
