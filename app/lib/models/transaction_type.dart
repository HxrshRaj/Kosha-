enum TransactionType {
  income,
  expense;

  static TransactionType fromJson(String value) =>
      TransactionType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => TransactionType.expense,
      );

  String toJson() => name;
}
