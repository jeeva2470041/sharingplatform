class UserWallet {
  double balance;
  double lockedDeposit;

  UserWallet({this.balance = 1000.0, this.lockedDeposit = 0.0});

  void lockDeposit(double amount) {
    if (balance >= amount) {
      balance -= amount;
      lockedDeposit += amount;
    }
  }

  void releaseDeposit(double amount) {
    lockedDeposit -= amount;
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
