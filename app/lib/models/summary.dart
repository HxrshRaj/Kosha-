class CategorySpend {
  final int categoryId;
  final String categoryName;
  final String color;
  final String icon;
  final double total;
  final double? budget;

  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.color,
    required this.icon,
    required this.total,
    required this.budget,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> json) => CategorySpend(
    categoryId: json['category_id'] as int,
    categoryName: json['category_name'] as String,
    color: json['color'] as String,
    icon: json['icon'] as String,
    total: (json['total'] as num).toDouble(),
    budget: (json['budget'] as num?)?.toDouble(),
  );
}

class MonthlySummary {
  final String month;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final List<CategorySpend> byCategory;

  const MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.byCategory,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
    month: json['month'] as String,
    totalIncome: (json['total_income'] as num).toDouble(),
    totalExpense: (json['total_expense'] as num).toDouble(),
    net: (json['net'] as num).toDouble(),
    byCategory: (json['by_category'] as List)
        .map((e) => CategorySpend.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static MonthlySummary empty(String month) => MonthlySummary(
    month: month,
    totalIncome: 0,
    totalExpense: 0,
    net: 0,
    byCategory: const [],
  );
}

class MonthPoint {
  final String month;
  final double totalIncome;
  final double totalExpense;

  const MonthPoint({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });

  factory MonthPoint.fromJson(Map<String, dynamic> json) => MonthPoint(
    month: json['month'] as String,
    totalIncome: (json['total_income'] as num).toDouble(),
    totalExpense: (json['total_expense'] as num).toDouble(),
  );
}

class YearlySummary {
  final int year;
  final List<MonthPoint> months;

  const YearlySummary({required this.year, required this.months});

  factory YearlySummary.fromJson(Map<String, dynamic> json) => YearlySummary(
    year: json['year'] as int,
    months: (json['months'] as List)
        .map((e) => MonthPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
