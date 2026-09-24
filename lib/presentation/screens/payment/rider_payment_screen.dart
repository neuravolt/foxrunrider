import 'payment_success_page.dart';
import 'dart:convert';
import 'package:ride_on/core/services/data_store.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/cubits/payment/coupon_cubit.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';

import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/location/get_nearby_drivers_cubit.dart';
import '../../cubits/payment/payment_cubit.dart';
import '../../cubits/wallet/wallet_cubit.dart';
import '../../cubits/realtime/get_ride_request_status_cubit.dart';
import '../../cubits/realtime/ride_request_cubit.dart';
import '../../cubits/realtime/update_ride_request_parameter.dart';
import '../../widgets/review_widget.dart';

class RiderPaymentScreen extends StatefulWidget {
  final String? bookingId, rideId, fare, paymentUrl;
  const RiderPaymentScreen({
    super.key,
    this.bookingId,
    this.rideId,
    this.fare,
    this.paymentUrl,
  });

  @override
  State<RiderPaymentScreen> createState() => _RiderPaymentScreenState();
}

class _RiderPaymentScreenState extends State<RiderPaymentScreen> {
  late final Razorpay _razorpay;
  Map<String, dynamic> vehicle = {};
  String paymentStatus = "";
  bool isCash = true;
  bool isOpenReview = false;
  TextEditingController couponController = TextEditingController();
  double originalFare = 0;
  double discountedFare = 0;
  double discountAmount = 0;
  bool couponApplied = false;
  bool _isOpeningCheckout = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    final savedCoupon = box.get("coupon") ?? "";
    currency = box.get("currency");

    final savedVehicle = box.get('selected_vehicle');
    if (savedVehicle != null && savedVehicle.isNotEmpty) {
      vehicle = jsonDecode(savedVehicle);
    }

    if (savedCoupon.isNotEmpty) {
      couponController.text = savedCoupon;
    }

    if ((widget.rideId ?? "").isNotEmpty) {
      context.read<GetRideRequestPaymentCubit>().resetStatus();
      context.read<GetRideRequestPaymentCubit>().listenToPaymentStatusAndMethod(
        rideId: widget.rideId!,
      );
    }

    originalFare = double.tryParse(widget.fare ?? '0') ?? 0.0;
    discountedFare = originalFare;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletCubit>().fetchWallet(context: context);
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    couponController.dispose();
    super.dispose();
  }

  void _applyCouponDiscount(double discount) {
    setState(() {
      discountAmount = discount;
      discountedFare = originalFare - discountAmount;
      couponApplied = true;
    });
  }

  void _removeCoupon() {
    context.read<CouponCubit>().removeCoupon(
      postData: {
        "item_type_id": vehicle["id"],
        "booking_id": widget.bookingId,
        "distance": vehicle["distance"],
        "coupon_code": "",
        "wallet_amount": "",
        "selected_currency_code": currency,
      },
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: MultiBlocListener(
        listeners: [
          BlocListener<GetRideRequestPaymentCubit, Map<String, String>>(
            listener: (context, state) {
              paymentStatus = state["paymentStatus"] ?? "";
            },
          ),
          BlocListener<UpdatePaymentByUserCubit, UpdatePaymentByUserState>(
            listener: (context, state) {
              if (state is UpdatePaymentLoading) {
                showLoading();
              } else if (state is UpdatePaymentSuceess) {
                closeLoading();
                final rideId = (widget.rideId ?? "").trim();
                goTo(BookingSuccessScreen(rideId: rideId));
              } else if (state is UpdatePaymentFailure) {
                closeLoading();
                showErrorToastMessage(state.paymentMessage ?? "Payment failed");
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: whiteColor,
          appBar: CustomAppBarNew(
            title: "Trip Summary".translate(context),
            onBackTap: () {
              context
                  .read<GetRideRequestPaymentCubit>()
                  .listenToPaymentStatusAndMethod(rideId: widget.rideId!);
              if (paymentStatus.toLowerCase() == "collected") {
                box.delete("ride_data");
                context.read<GetPolylineCubit>().resetPolylines();
                context.read<BookRideRealTimeDataBaseCubit>().resetState();
                clearAllRiderData(context);
                goTo(const ItemHomeScreen());
              } else {
                dialogExit(context);
              }
            },
          ),
          body: BlocListener<GetRideRequestPaymentCubit, Map<String, String>>(
            listener: (context, state) {
              if (state["paymentMethod"] == "cash") {
                context.read<PaymentCubit>().selectMethod(PaymentMethod.cash);
              } else if (state["paymentMethod"] == "wallet") {
                context.read<PaymentCubit>().selectMethod(PaymentMethod.wallet);
              } else {
                context.read<PaymentCubit>().selectMethod(PaymentMethod.online);
              }

              if (state["paymentStatus"] == "collected") {
                paymentStatus = "collected";
                box.delete("ride_data");
                context.read<GetPolylineCubit>().resetPolylines();
                context.read<BookRideRealTimeDataBaseCubit>().resetState();
                if (isOpenReview) return;
                isOpenReview = true;
                clearAllRiderData(context);
                showModalBottomSheet(
                  context: context,
                  enableDrag: false,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      CustomReviewWidget(bookingId: widget.bookingId),
                );
              }
            },
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 3,
                  margin: const EdgeInsets.only(top: 0, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: BlocBuilder<PaymentCubit, PaymentMethod?>(
                      builder: (context, selectedMethod) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDriverInfoSection(context),

                        const SizedBox(height: 20),

                        _buildRouteInfoSection(context),

                        const SizedBox(height: 20),
                        Column(
                          children: [
                            _buildCouponSection(context),
                            const SizedBox(height: 10),
                            _buildFareBreakdown(context),
                          ],
                        ),
                        

                        // Payment Methods
                        _buildPaymentMethods(context, selectedMethod),

                        const SizedBox(height: 30),

                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          _buildBottomPayButton(context),
        ],
      ),
    ),
  ),
  ),
);
}


  Widget _buildBottomPayButton(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentMethod?>(
      builder: (context, selectedMethod) {
        return Container(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 16),
          decoration: BoxDecoration(
            color: whiteColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (selectedMethod == PaymentMethod.online) {
                    _redirectToOnlinePayment(context);
                  } else if (selectedMethod == PaymentMethod.wallet) {
                    _processWalletPayment(context);
                  } else {
                    _processCashPayment(context);
                  }
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security, color: Colors.black87, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Pay $currency ${discountedFare.toStringAsFixed(2)}",
                        style: headingBlack(context).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "100% Secure Payments".translate(context),
                    style: regular(context).copyWith(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverInfoSection(BuildContext context) {
    return BlocBuilder<RideRequestCubit, RideRequestState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 65,
                width: 65,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFB800), width: 2),
                ),
                child: state.acceptedDriverImageUrl.isEmpty
                    ? Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF9ED),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Color(0xFFFFB800), size: 40),
                      )
                    : ClipOval(
                        child: myNetworkImage(state.acceptedDriverImageUrl),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.acceptedDriverName,
                      style: headingBlack(
                        context,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.green.shade50.withOpacity(0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "RIDE COMPLETE".translate(context),
                            style: regular(context).copyWith(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteInfoSection(BuildContext context) {
    return BlocBuilder<RideRequestCubit, RideRequestState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FFF9),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location,
                      size: 16,
                      color: Colors.green,
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 40,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade300, Colors.red.shade300],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag, size: 16, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pickup".translate(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.pickupAddress,
                      style: heading3Grey1(context).copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                    const SizedBox(height: 12),
                    Text(
                      "Drop".translate(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.dropOffAddress,
                      style: heading3Grey1(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCouponSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFF0B3), width: 1.5, style: BorderStyle.solid), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_activity, color: Color(0xFFFFB800), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  style: headingBlack(context).copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                  controller: couponController,
                  decoration: InputDecoration(
                    hintText: "Enter coupon code".translate(context),
                    hintStyle: regular(context).copyWith(fontSize: 12, color: Colors.grey.shade600),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixIcon: couponApplied
                        ? IconButton(
                            icon: Icon(Icons.close, color: redColor),
                            onPressed: _removeCoupon,
                          )
                        : null,
                  ),
                ),
              ),
              BlocConsumer<CouponCubit, PaymentCouponState>(
                listener: (context, state) {
                  if (state is CouponSuccessState) {
                    double discount = double.parse(
                      state.getItemPriceData?.data?.couponDiscount ?? "0",
                    );
                    _applyCouponDiscount(discount);
                    context
                        .read<UpdateRideRequestParameterCubit>()
                        .updatePaymentAmountFirebase(
                          rideId: widget.rideId ?? "",
                          totalFare: discountedFare.toStringAsFixed(2),
                          discountFare: discountAmount.toString(),
                          couponApply: "yes",
                        );
                    context.read<CouponCubit>().resetCoupon();
                  } else if (state is CouponFailedState) {
                    String errorMsg = state.message.trim();
                    if (errorMsg == "global.invalid_coupon_code" ||
                        errorMsg.contains("invalid_coupon_code")) {
                      errorMsg = "Invalid coupon code".translate(context);
                    } else if (errorMsg.startsWith("global.")) {
                      errorMsg = errorMsg
                          .replaceAll("global.", "")
                          .replaceAll("_", " ")
                          .translate(context);
                    }
                    showErrorToastMessage(errorMsg);
                    context.read<CouponCubit>().resetCoupon();
                  } else if (state is CouponRemoveState) {
                    couponController.clear();
                    discountAmount = 0;
                    discountedFare = originalFare;
                    couponApplied = false;
                    context
                        .read<UpdateRideRequestParameterCubit>()
                        .updatePaymentAmountFirebase(
                          rideId: widget.rideId ?? "",
                          totalFare: discountedFare.toStringAsFixed(2),
                          discountFare: discountAmount.toString(),
                          couponApply: "no",
                        );
                    context.read<CouponCubit>().resetCoupon();
                    setState(() {});
                  }
                },
                builder: (context, state) {
                  return GestureDetector(
                    onTap: state is CouponLoadingState
                        ? null
                        : () {
                            if (couponApplied) {
                              return;
                            }
                            if (couponController.text.isEmpty) {
                              showErrorToastMessage(
                                "Please enter coupon code",
                              );
                              return;
                            }
                            context.read<CouponCubit>().applyCoupon(
                              postData: {
                                "item_type_id": vehicle["id"],
                                "booking_id": widget.bookingId,
                                "distance": vehicle["distance"],
                                "coupon_code": couponController.text,
                                "wallet_amount": "",
                                "selected_currency_code": currency,
                              },
                              context: context,
                            );
                          },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB800), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: state is CouponLoadingState
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFB800),
                                ),
                              ),
                            )
                          : Text(
                              couponApplied && discountAmount != 0
                                  ? "Applied".translate(context)
                                  : "Apply".translate(context),
                              style: regular(context).copyWith(color: const Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
          
          if (couponApplied && discountAmount != 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Coupon applied successfully!".translate(context),
                    style: regular(context).copyWith(color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFareBreakdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Fare Breakdown".translate(context),
                style: headingBlack(
                  context,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFareRow(
            "Original Fare".translate(context),
            originalFare.toStringAsFixed(2),
            isTotal: false,
          ),
          if (couponApplied && discountAmount != 0) ...[
            _buildFareRow(
              "Discount".translate(context),
              "-${discountAmount.toStringAsFixed(2)}",
              isTotal: false,
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: Colors.grey.withOpacity(0.2), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Amount".translate(context),
                style: headingBlack(context).copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "$currency ${discountedFare.toStringAsFixed(2)}",
                style: headingBlack(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFB800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(
    String label,
    String amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.translate(context),
            style: regular(context).copyWith(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isDiscount ? greentext : blackColor.withValues(alpha: 0.8),
            ),
          ),
          Text(
            "$currency $amount",
            style: regular(context).copyWith(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal
                  ? themeColor
                  : isDiscount
                  ? greentext
                  : blackColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(
    BuildContext context,
    PaymentMethod? selectedMethod,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Method".translate(context),
            style: headingBlack(
              context,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 12),

          // Cash Payment Option
          _buildPaymentOption(
            context: context,
            icon: Icons.attach_money,
            title: "Cash".translate(context),
            subtitle: "Pay with cash to driver".translate(context),
            method: PaymentMethod.cash,
            selectedMethod: selectedMethod,
          ),

          const SizedBox(height: 12),

          // Online Payment Option
          _buildPaymentOption(
            context: context,
            icon: Icons.credit_card,
            title: "Online".translate(context),
            subtitle: "Pay securely online".translate(context),
            method: PaymentMethod.online,
            selectedMethod: selectedMethod,
          ),

          const SizedBox(height: 12),

          // Wallet Payment Option
          _buildPaymentOption(
            context: context,
            icon: Icons.account_balance_wallet_outlined,
            title: "Wallet".translate(context),
            subtitle: "Pay using wallet balance (₹${context.read<WalletCubit>().currentBalance.toStringAsFixed(2)})".translate(context),
            method: PaymentMethod.wallet,
            selectedMethod: selectedMethod,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required PaymentMethod method,
    required PaymentMethod? selectedMethod,
  }) {
    bool isSelected = selectedMethod == method;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? themeColor.withValues(alpha: 0.1)
            : notifires.getboxcolor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? themeColor : grey5.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? themeColor : grey5.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected ? whiteColor : blackColor.withValues(alpha: 0.7),
          ),
        ),
        title: Text(
          title,
          style: headingBlack(
            context,
          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle.translate(context),
          style: regular(
            context,
          ).copyWith(fontSize: 12, color: blackColor.withValues(alpha: 0.6)),
        ),
        trailing: Radio<PaymentMethod>(
          activeColor: themeColor,
          value: method,
          groupValue: selectedMethod,
          onChanged: (value) {
            if (value != null) {
              context.read<PaymentCubit>().selectMethod(value);
              context
                  .read<UpdateRideRequestParameterCubit>()
                  .updatePaymentMehod(
                    rideId: widget.rideId ?? "",
                    paymentMethod: value == PaymentMethod.cash
                        ? "cash"
                        : value == PaymentMethod.wallet
                            ? "wallet"
                            : "online",
                  );
              if (value == PaymentMethod.online) {
                _redirectToOnlinePayment(context);
              } else if (value == PaymentMethod.wallet) {
                _processWalletPayment(context);
              }
            }
          },
        ),
        onTap: () {
          context.read<PaymentCubit>().selectMethod(method);
          context.read<UpdateRideRequestParameterCubit>().updatePaymentMehod(
            rideId: widget.rideId ?? "",
            paymentMethod: method == PaymentMethod.cash
                ? "cash"
                : method == PaymentMethod.wallet
                    ? "wallet"
                    : "online",
          );
          if (method == PaymentMethod.online) {
            _redirectToOnlinePayment(context);
          } else if (method == PaymentMethod.wallet) {
            _processWalletPayment(context);
          }
        },
      ),
    );
  }


  Future<void> _processCashPayment(BuildContext context) async {
    final bookingId = (widget.bookingId ?? "").trim();
    final rideId = (widget.rideId ?? "").trim();

    if (bookingId.isNotEmpty) {
      context.read<UpdatePaymentByUserCubit>().updatePaymentStatusByUser(
            context: context,
            bookingId: bookingId,
            paymentMethod: "cash",
          );
    } else if (rideId.isNotEmpty) {
      goTo(BookingSuccessScreen(rideId: rideId));
    } else {
      showErrorToastMessage("Invalid booking or ride details.");
    }
  }

  Future<void> _processWalletPayment(BuildContext context) async {
    showLoading();
    try {
      await context.read<WalletCubit>().fetchWallet(context: context);
      final walletCubit = context.read<WalletCubit>();
      final balance = walletCubit.currentBalance;
      closeLoading();

      if (balance < discountedFare) {
        showErrorToastMessage("Insufficient wallet balance. Please select another method or top up.");
        context.read<PaymentCubit>().selectMethod(PaymentMethod.cash);
        context.read<UpdateRideRequestParameterCubit>().updatePaymentMehod(
              rideId: widget.rideId ?? "",
              paymentMethod: "cash",
            );
        return;
      }

      // Deduct from wallet and complete payment
      context.read<UpdatePaymentByUserCubit>().updatePaymentStatusByUser(
            context: context,
            bookingId: widget.bookingId ?? "",
            paymentMethod: "wallet",
          );
    } catch (e) {
      closeLoading();
      showErrorToastMessage("Failed to process wallet payment: $e");
    }
  }

  Future<void> _redirectToOnlinePayment(BuildContext context) async {
    if (_isOpeningCheckout) return;
    _isOpeningCheckout = true;
    final checkoutOptions = await _buildRazorpayOptions();
    _isOpeningCheckout = false;
    if (checkoutOptions == null) {
      showErrorToastMessage("Unable to open payment checkout");
      return;
    }
    try {
      _razorpay.open(checkoutOptions);
    } catch (_) {
      showErrorToastMessage("Unable to open payment checkout");
    }
  }

  Future<Map<String, dynamic>?> _buildRazorpayOptions() async {
    final paymentUri = Uri.tryParse((widget.paymentUrl ?? "").trim());
    if (paymentUri == null) return null;
    final bookingIdFromUrl = paymentUri.queryParameters['booking'] ?? "";
    final bookingId = (widget.bookingId ?? "").isNotEmpty
        ? widget.bookingId!.trim()
        : bookingIdFromUrl.trim();
    if (bookingId.isEmpty) return null;

    final postUri = paymentUri.replace(path: '/payment', queryParameters: {});
    final paymentInitResponse = await http.post(
      postUri,
      body: {'booking': bookingId, 'method': 'razorpay'},
    );
    if (paymentInitResponse.statusCode < 200 ||
        paymentInitResponse.statusCode >= 300) {
      return null;
    }

    final html = paymentInitResponse.body;
    final key = _firstMatch(html, r'"key"\s*:\s*"([^"]+)"');
    final amountText = _firstMatch(html, r'"amount"\s*:\s*"([^"]+)"');
    final currency = _firstMatch(html, r'"currency"\s*:\s*"([^"]+)"') ?? "INR";
    final orderId = _firstMatch(html, r'"order_id"\s*:\s*"([^"]+)"');
    final amount = int.tryParse(amountText ?? "");

    if (key == null || orderId == null || amount == null || amount <= 0) {
      return null;
    }

    return <String, dynamic>{
      'key': key.trim(),
      'amount': amount,
      'currency': currency.trim(),
      'name': "RideOn",
      'description': "Ride Payment",
      'order_id': orderId.trim(),
      'prefill': {
        'contact': _getUserPhoneForPrefill(),
        'email': _getUserEmailForPrefill(),
      },
      'retry': {'enabled': true, 'max_count': 1},
    };
  }

  String _getUserPhoneForPrefill() {
    final data = loginModel?.data;
    final country = (data?.phoneCountry ?? "").trim();
    final phone = (data?.phone ?? "").trim();
    final combined = "$country$phone".replaceAll(" ", "");
    if (combined.isNotEmpty) return combined;
    return phone;
  }

  String _getUserEmailForPrefill() {
    return (loginModel?.data?.email ?? socialEmail).trim();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint("Razorpay success: ${response.paymentId}");
    final isConfirmed = await _confirmPaymentOnServer(response);
    if (!mounted) return;
    if (!isConfirmed) {
      showErrorToastMessage("Unable to verify payment status");
      return;
    }

    final rideId = (widget.rideId ?? "").trim();
    goTo(BookingSuccessScreen(rideId: rideId));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final message = response.message?.trim();
    if (message != null && message.isNotEmpty) {
      showErrorToastMessage(message);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("Razorpay external wallet: ${response.walletName}");
  }

  Future<bool> _confirmPaymentOnServer(PaymentSuccessResponse response) async {
    final paymentUri = Uri.tryParse((widget.paymentUrl ?? "").trim());
    if (paymentUri == null) return false;
    final bookingIdFromUrl = paymentUri.queryParameters['booking'] ?? "";
    final bookingId = (widget.bookingId ?? "").isNotEmpty
        ? widget.bookingId!.trim()
        : bookingIdFromUrl.trim();
    if (bookingId.isEmpty) return false;

    final returnUri = paymentUri.replace(
      path: '/payment/return',
      queryParameters: {
        'booking': bookingId,
        'method': 'razorpay',
        'razorpay_payment_id': response.paymentId ?? '',
        'razorpay_order_id': response.orderId ?? '',
        'razorpay_signature': response.signature ?? '',
      },
    );

    try {
      final response = await http.get(returnUri);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  String? _firstMatch(String input, String pattern) {
    final match = RegExp(pattern).firstMatch(input);
    if (match == null || match.groupCount < 1) return null;
    final value = match.group(1);
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
