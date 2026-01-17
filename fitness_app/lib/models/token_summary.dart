class TokenLog {
  final int amount;
  final DateTime createdAt;
  final String typeName;

  TokenLog({
    required this.amount,
    required this.createdAt,
    required this.typeName,
  });

  factory TokenLog.fromJson(Map<String, dynamic> json) {
    return TokenLog(
      amount: json['amount'],
      createdAt: DateTime.parse(json['created_at']),
      typeName: json['type_name'],
    );
  }
}

class TokenSummary {
  final int totalTokens;
  final List<TokenLog> history;

  TokenSummary({
    required this.totalTokens,
    required this.history,
  });

  factory TokenSummary.fromJson(Map<String, dynamic> json) {
    var historyFromJson = json['history'] as List;
    List<TokenLog> historyList =
        historyFromJson.map((i) => TokenLog.fromJson(i)).toList();

    return TokenSummary(
      totalTokens: json['totalTokens'],
      history: historyList,
    );
  }
}
