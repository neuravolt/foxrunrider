import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:ride_on/core/utils/common_widget.dart';
import 'package:ride_on/core/utils/theme/project_color.dart';
import 'package:ride_on/core/utils/theme/theme_style.dart';
import 'package:ride_on/core/utils/translate.dart';
import '../../cubits/wallet/wallet_cubit.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final Razorpay _razorpay;
  final TextEditingController _amountController = TextEditingController();
  double? _selectedAmount;
  bool _isInitiatingPayment = false;
  late ColorNotifires _notifiers;

  // Track the Razorpay order parameters to verify them on success
  String? _currentOrderId;
  double? _currentRechargeAmount;
  String? _currentCurrency;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Fetch current wallet details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletCubit>().fetchWallet(context: context);
      context.read<WalletCubit>().fetchTransactions(context: context);
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_currentOrderId == null || _currentRechargeAmount == null) {
      showErrorToastMessage("Payment confirmation data missing");
      return;
    }

    context.read<WalletCubit>().verifyRecharge(
          context: context,
          orderId: _currentOrderId!,
          paymentId: response.paymentId ?? '',
          signature: response.signature ?? '',
          amount: _currentRechargeAmount!,
          currency: _currentCurrency ?? 'INR',
        );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isInitiatingPayment = false;
    });
    final message = response.message ?? "Payment failed or cancelled";
    showErrorToastMessage(message);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External wallet selected: ${response.walletName}");
  }

  void _onQuickAmountSelect(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _startTopUp() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 1) {
      showErrorToastMessage("Minimum recharge amount is INR 1".translate(context));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isInitiatingPayment = true;
    });

    _currentRechargeAmount = amount;
    _currentCurrency = 'INR';

    await context.read<WalletCubit>().initiateRecharge(
          context: context,
          amount: amount,
          currency: 'INR',
        );
  }

  void _launchRazorpayCheckout(WalletRechargeOrderSuccess state) {
    _currentOrderId = state.orderId;
    
    final options = <String, dynamic>{
      'key': state.apiKey,
      'amount': (state.amount * 100).toInt(), // Convert to Paisa
      'currency': state.currency,
      'name': "Foxrun Wallet",
      'description': "Wallet Top Up",
      'order_id': state.orderId,
      'prefill': state.prefill,
      'retry': {'enabled': true, 'max_count': 1},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _isInitiatingPayment = false;
      });
      showErrorToastMessage("Could not launch payment screen");
    }
  }

  @override
  Widget build(BuildContext context) {
    _notifiers = Provider.of<ColorNotifires>(context, listen: true);

    return Scaffold(
      backgroundColor: _notifiers.getbgcolor,
      appBar: CustomAppBarNew(
        title: "Wallet",
        backgroundColor: _notifiers.getbgcolor,
        titleColor: _notifiers.getwhiteblackColor,
      ),
      body: BlocListener<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletRechargeOrderSuccess) {
            _launchRazorpayCheckout(state);
          } else if (state is WalletRechargeSuccess) {
            setState(() {
              _isInitiatingPayment = false;
              _amountController.clear();
              _selectedAmount = null;
            });
            showToastMessage(state.message);
            // Refresh wallet & transactions
            context.read<WalletCubit>().fetchWallet(context: context);
            context.read<WalletCubit>().fetchTransactions(context: context);
          } else if (state is WalletRechargeFailure) {
            setState(() {
              _isInitiatingPayment = false;
            });
            showErrorToastMessage(state.message);
          } else if (state is WalletFailure) {
            showErrorToastMessage(state.message);
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<WalletCubit>().fetchWallet(context: context);
            context.read<WalletCubit>().fetchTransactions(context: context);
          },
          color: themeColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet Balance Card
                BlocBuilder<WalletCubit, WalletState>(
                  buildWhen: (prev, curr) => curr is WalletSuccess || curr is WalletLoading || curr is WalletFailure,
                  builder: (context, state) {
                    final cubit = context.read<WalletCubit>();
                    final balance = cubit.currentBalance;
                    final currency = cubit.currentCurrency;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [themeColor, themeColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Your Balance".translate(context),
                                style: heading3(context).copyWith(
                                  color: Colors.black.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.black,
                                size: 28,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "$currency ",
                                style: heading1(context).copyWith(
                                  fontSize: 24,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                balance.toStringAsFixed(2),
                                style: heading1(context).copyWith(
                                  fontSize: 36,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (state is WalletLoading && !_isInitiatingPayment) ...[
                            const SizedBox(height: 10),
                            const SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),

                // Top Up Section
                Text(
                  "Add Money to Wallet".translate(context),
                  style: headingBlack(context).copyWith(
                    color: _notifiers.getwhiteblackColor,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _notifiers.getboxcolor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _notifiers.getGrey3whiteColor),
                  ),
                  child: Column(
                    children: [
                      // Amount Input Field
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        style: headingBlack(context).copyWith(color: _notifiers.getwhiteblackColor),
                        decoration: InputDecoration(
                          hintText: "Enter amount".translate(context),
                          hintStyle: heading3Grey1(context),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                            child: Text(
                              "INR",
                              style: heading2Grey1(context).copyWith(
                                color: _notifiers.getwhiteblackColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _notifiers.getGrey3whiteColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _notifiers.getGrey3whiteColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: themeColor, width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _selectedAmount = double.tryParse(val);
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // Quick Selector Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [100.0, 200.0, 500.0, 1000.0].map((amt) {
                          final isSelected = _selectedAmount == amt;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: OutlinedButton(
                                onPressed: () => _onQuickAmountSelect(amt),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isSelected ? themeColor : _notifiers.getGrey3whiteColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  backgroundColor: isSelected ? themeColor.withOpacity(0.1) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "+₹${amt.toStringAsFixed(0)}",
                                  style: heading3(context).copyWith(
                                    color: isSelected ? themeColor : _notifiers.getwhiteblackColor,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      _isInitiatingPayment
                          ? CircularProgressIndicator(color: themeColor)
                          : CustomsButtons(
                              text: "Add Money",
                              backgroundColor: themeColor,
                              textColor: Colors.black,
                              onPressed: _startTopUp,
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Transactions List Section
                Text(
                  "Recent Transactions".translate(context),
                  style: headingBlack(context).copyWith(
                    color: _notifiers.getwhiteblackColor,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 15),

                BlocBuilder<WalletCubit, WalletState>(
                  builder: (context, state) {
                    final cubit = context.read<WalletCubit>();
                    
                    if (state is WalletLoading && !_isInitiatingPayment) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: themeColor),
                        ),
                      );
                    }

                    final transactions = cubit.currentTransactions;

                    if (transactions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: Text(
                            "No transactions yet".translate(context),
                            style: heading3Grey1(context),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => Divider(
                        color: _notifiers.getGrey3whiteColor,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final type = tx['type']?.toString() ?? 'unknown';
                        final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
                        final note = tx['note']?.toString() ?? '';
                        final dateStr = tx['created_at']?.toString() ?? '';

                        final isCredit = ['credit', 'admin_credit', 'wallet_topup', 'refund'].contains(type);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            type.replaceAll('_', ' ').toUpperCase().translate(context),
                            style: heading2(context).copyWith(
                              fontSize: 14,
                              color: _notifiers.getwhiteblackColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            note.isNotEmpty ? note : dateStr,
                            style: heading3Grey1(context).copyWith(fontSize: 12),
                          ),
                          trailing: Text(
                            "${isCredit ? '+' : '-'}${cubit.currentCurrency} ${amount.toStringAsFixed(2)}",
                            style: heading2(context).copyWith(
                              fontSize: 15,
                              color: isCredit ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
