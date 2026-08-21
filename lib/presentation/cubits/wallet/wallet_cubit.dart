import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/wallet_repository.dart';

abstract class WalletState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletSuccess extends WalletState {
  final double balance;
  final String currency;
  final String status;

  WalletSuccess({
    required this.balance,
    required this.currency,
    required this.status,
  });

  @override
  List<Object?> get props => [balance, currency, status];
}

class WalletFailure extends WalletState {
  final String message;
  WalletFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class WalletTransactionsSuccess extends WalletState {
  final List<dynamic> transactions;
  final int total;

  WalletTransactionsSuccess({
    required this.transactions,
    required this.total,
  });

  @override
  List<Object?> get props => [transactions, total];
}

class WalletRechargeOrderSuccess extends WalletState {
  final String orderId;
  final double amount;
  final String currency;
  final String apiKey;
  final Map<String, dynamic> prefill;

  WalletRechargeOrderSuccess({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.apiKey,
    required this.prefill,
  });

  @override
  List<Object?> get props => [orderId, amount, currency, apiKey, prefill];
}

class WalletRechargeLoading extends WalletState {}

class WalletRechargeSuccess extends WalletState {
  final double newBalance;
  final String currency;
  final String message;

  WalletRechargeSuccess({
    required this.newBalance,
    required this.currency,
    required this.message,
  });

  @override
  List<Object?> get props => [newBalance, currency, message];
}

class WalletRechargeFailure extends WalletState {
  final String message;
  WalletRechargeFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository walletRepository;

  WalletCubit(this.walletRepository) : super(WalletInitial());

  double currentBalance = 0.0;
  String currentCurrency = 'INR';
  String currentStatus = 'active';
  List<dynamic> currentTransactions = [];

  void resetWallet() {
    currentBalance = 0.0;
    currentCurrency = 'INR';
    currentStatus = 'active';
    currentTransactions.clear();
    emit(WalletInitial());
  }

  Future<void> fetchWallet({required BuildContext context}) async {
    try {
      emit(WalletLoading());
      final res = await walletRepository.getWallet(context: context);
      
      if (res['status'] == 200 && res['data'] != null) {
        currentBalance = double.tryParse(res['data']['balance']?.toString() ?? '0') ?? 0.0;
        currentCurrency = res['data']['currency']?.toString() ?? 'INR';
        currentStatus = res['data']['status']?.toString() ?? 'active';
        
        emit(WalletSuccess(
          balance: currentBalance,
          currency: currentCurrency,
          status: currentStatus,
        ));
      } else {
        emit(WalletFailure(res['message']?.toString() ?? 'Failed to load wallet'));
      }
    } catch (e) {
      emit(WalletFailure(e.toString()));
    }
  }

  Future<void> fetchTransactions({
    required BuildContext context,
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      emit(WalletLoading());
      final res = await walletRepository.getWalletTransactions(
        context: context,
        limit: limit,
        offset: offset,
      );

      if (res['status'] == 200 && res['data'] != null) {
        currentTransactions = res['data']['transactions'] ?? [];
        emit(WalletTransactionsSuccess(
          transactions: currentTransactions,
          total: res['data']['total'] ?? 0,
        ));
      } else {
        emit(WalletFailure(res['message']?.toString() ?? 'Failed to load transactions'));
      }
    } catch (e) {
      emit(WalletFailure(e.toString()));
    }
  }

  Future<void> initiateRecharge({
    required BuildContext context,
    required double amount,
    String currency = 'INR',
  }) async {
    try {
      emit(WalletLoading());
      final res = await walletRepository.addMoney(
        context: context,
        amount: amount,
        currency: currency,
      );

      if (res['status'] == 200 && res['data'] != null) {
        final data = res['data'];
        emit(WalletRechargeOrderSuccess(
          orderId: data['razorpay_order_id'],
          amount: double.tryParse(data['amount']?.toString() ?? '0') ?? amount,
          currency: data['currency'] ?? currency,
          apiKey: data['api_key'],
          prefill: Map<String, dynamic>.from(data['prefill'] ?? {}),
        ));
      } else {
        emit(WalletRechargeFailure(res['message']?.toString() ?? 'Failed to create topup order'));
      }
    } catch (e) {
      emit(WalletRechargeFailure(e.toString()));
    }
  }

  Future<void> verifyRecharge({
    required BuildContext context,
    required String orderId,
    required String paymentId,
    required String signature,
    required double amount,
    String currency = 'INR',
  }) async {
    try {
      emit(WalletRechargeLoading());
      final res = await walletRepository.verifyPayment(
        context: context,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        amount: amount,
        currency: currency,
      );

      if (res['status'] == 200 && res['data'] != null) {
        currentBalance = double.tryParse(res['data']['balance']?.toString() ?? '0') ?? 0.0;
        currentCurrency = res['data']['currency']?.toString() ?? currency;
        
        emit(WalletRechargeSuccess(
          newBalance: currentBalance,
          currency: currentCurrency,
          message: res['message']?.toString() ?? 'Wallet recharged successfully!',
        ));
      } else {
        emit(WalletRechargeFailure(res['message']?.toString() ?? 'Payment verification failed'));
      }
    } catch (e) {
      emit(WalletRechargeFailure(e.toString()));
    }
  }
}
