class Transaction {
  final String id;
  final String clientId;
  final String userId;
  final String type; // 'debt' o 'payment'
  final double amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.clientId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id']?.toString() ?? '',
    clientId: map['client_id']?.toString() ?? '',
    userId: map['user_id']?.toString() ?? '',
    type: map['type'],
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    description: map['description'] ?? '',
    date: DateTime.parse(map['date']),
    createdAt: DateTime.parse(map['created_at']),
  );
}
