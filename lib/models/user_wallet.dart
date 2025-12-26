class UserWallet {
  double balance;
  double lockedDeposit;
  List<String> activeTransactionIds;

  UserWallet({
    this.balance = 1000.0,
    this.lockedDeposit = 0.0,
    List<String>? activeTransactionIds,
  }) : activeTransactionIds = activeTransactionIds ?? [];

  /// Lock deposit when borrower requests an item
  /// Deducts from balance and adds to lockedDeposit
  void lockDeposit(double amount, [String? transactionId]) {
    if (balance >= amount) {
      balance -= amount;
      lockedDeposit += amount;
      if (transactionId != null) {
        activeTransactionIds.add(transactionId);
      }
    }
  }

  /// Release locked deposit back to balance (e.g., when item is returned)
  void releaseDeposit(double amount, [String? transactionId]) {
    if (lockedDeposit >= amount) {
      lockedDeposit -= amount;
      balance += amount;
      if (transactionId != null) {
        activeTransactionIds.remove(transactionId);
      }
    }
  }

  /// Transfer locked deposit to another wallet (e.g., when item is damaged/kept)
  /// Returns true if successful
  bool transferLockedDeposit(double amount, [String? transactionId]) {
    if (lockedDeposit >= amount) {
      lockedDeposit -= amount;
      // Deposit is transferred out, not returned to balance
      if (transactionId != null) {
        activeTransactionIds.remove(transactionId);
      }
      return true;
    }
    return false;
  }

  /// Add received deposit to balance (called on lender's wallet)
  void receiveTransferredDeposit(double amount) {
    balance += amount;
  }

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'lockedDeposit': lockedDeposit,
    'activeTransactionIds': activeTransactionIds,
  };

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      balance: (json['balance'] as num?)?.toDouble() ?? 1000.0,
      lockedDeposit: (json['lockedDeposit'] as num?)?.toDouble() ?? 0.0,
      activeTransactionIds:
          (json['activeTransactionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
