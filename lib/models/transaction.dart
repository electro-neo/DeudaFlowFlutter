class Transaction {
  final String id;
  final String clientId;
  final String userId;
  final String type; // 'debt' o 'payment'
  final double amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final bool? synced;
  final bool? pendingDelete;
  final String? localId;

  Transaction({
    required this.id,
    required this.clientId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    this.synced,
    this.pendingDelete,
    this.localId,
  });

  Transaction copyWith({
    String? id,
    String? clientId,
    String? userId,
    String? type,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    bool? synced,
    bool? pendingDelete,
    String? localId,
  }) {
    return Transaction(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      localId: localId ?? this.localId,
    );
  }

  static Transaction fromHive(dynamic t) {
    return Transaction(
      id: t.id,
      clientId: t.clientId,
      userId: '',
      type: t.type,
      amount: t.amount,
      description: t.description,
      date: t.date,
      createdAt: t.date,
      synced: t.synced,
      pendingDelete: t.pendingDelete,
    );
  }

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id']?.toString() ?? '',
    clientId: map['client_id']?.toString() ?? '',
    userId: map['user_id']?.toString() ?? '',
    type: map['type'],
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    description: map['description'] ?? '',
    date: DateTime.parse(map['date']),
    createdAt: DateTime.parse(map['created_at']),
    synced: map['synced'] is bool
        ? map['synced'] as bool
        : (map['synced'] is int ? (map['synced'] == 1) : null),
    pendingDelete: map['pendingDelete'] is bool
        ? map['pendingDelete'] as bool
        : (map['pendingDelete'] is int ? (map['pendingDelete'] == 1) : null),
    localId: map['local_id']?.toString(),
  );

  // Elimina el factory duplicado para evitar conflicto con el método estático
}
