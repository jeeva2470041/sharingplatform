class UserWallet {
  double balance;
  double lockedDeposit;

  UserWallet({this.balance = 1000.0, this.lockedDeposit = 0.0});

  /// Lock deposit when borrower requests an item
  /// Deducts from balance and adds to lockedDeposit
  void lockDeposit(double amount) {
    if (balance >= amount) {
      balance -= amount;
      lockedDeposit += amount;
    }
  }

  /// Release locked deposit back to balance (e.g., when item is returned)
  void releaseDeposit(double amount) {
    if (lockedDeposit >= amount) {
      lockedDeposit -= amount;
      balance += amount;
    }
  }

  /// Transfer locked deposit to another wallet (e.g., when item is damaged/kept)
  /// Returns true if successful
  bool transferLockedDeposit(double amount) {
    if (lockedDeposit >= amount) {
      lockedDeposit -= amount;
      // Deposit is transferred out, not returned to balance
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
      };

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      balance: (json['balance'] as num?)?.toDouble() ?? 1000.0,
      lockedDeposit: (json['lockedDeposit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
