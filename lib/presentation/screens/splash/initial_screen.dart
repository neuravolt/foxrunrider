import 'dart:async';
import 'dart:convert';
import 'package:ride_on/app/route_settings.dart';
import 'package:ride_on/domain/entities/ride_request.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/on_boarding_screen.dart';
import 'package:ride_on/presentation/screens/search/send_ride_request_screen.dart';
import 'package:ride_on/presentation/screens/splash/splash_screen.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/realtime/check_ride_request_cubit.dart';
import '../../cubits/realtime/ride_request_cubit.dart';

import '../payment/rider_payment_screen.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  late Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('appBox');
    handleNavigation();
    getCurrency(context);
  }

  // ignore: prefer_typing_uninitialized_variables
  var data;
  RideRequest? ridedata;

  void handleNavigation() {
    bool isFirstUser = false;
    try {
      isFirstUser = box.get('Firstuser', defaultValue: false) != true;
    } catch (_) {}

    final duration = Duration(milliseconds: isFirstUser ? 1000 : 800);
    Timer(duration, () {
      try {
        if (isFirstUser) {
          goToWithReplacement(const Onboardingscreen());
        } else {
          data = box.get('ride_data');
          if (data == null || data is! Map || (data["rideId"] ?? "").toString().isEmpty) {
            box.delete('ride_data');
            goToWithReplacement(const ItemHomeScreen());
          } else {
            String rideId = data["rideId"].toString();
            context.read<CheckStatusCubit>().checkStatus(rideId).timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                box.delete('ride_data');
                goToWithReplacement(const ItemHomeScreen());
              },
            );
          }
        }
      } catch (e) {
        goToWithReplacement(const ItemHomeScreen());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    return Scaffold(
      backgroundColor: Provider.of<ColorNotifires>(context).getbgcolor,
      body: BlocListener<CheckStatusCubit, CheckRideStatusState>(
          listener: (context, state) {
            if (state is CheckRideSuccess) {
              try {
                context.read<RideRequestCubit>().loadRideFromHive();

                final bookride = context.read<BookRideRealTimeDataBaseCubit>();
                if (data is Map) {
                  bookride.updatePickupLatAndLng(
                      pickupAddressLatitude: (data["pickLat"] ?? "").toString(),
                      pickupAddressLongitude: (data["pickLng"] ?? "").toString());
                  bookride.updateDropOffLatAndLng(
                      dropoffAddressLatitude: (data["dropLat"] ?? "").toString(),
                      dropoffAddressLongitude: (data["dropLng"] ?? "").toString());
                  bookride.updateDropOffAddress(
                      dropoffAddress: (data["dropAddress"] ?? "").toString());
                  bookride.updatePickupAddress(
                      pickupAddress: (data["pickAddress"] ?? "").toString());
                }

                Map<String, dynamic> vehicle = {};
                final rawVehicle = box.get('selected_vehicle');
                if (rawVehicle != null && rawVehicle.toString().isNotEmpty) {
                  vehicle = jsonDecode(rawVehicle.toString());
                }

                if (state.status == "accepted") {
                  goToWithReplacement(SendRideRequestScreen(
                    selectedVehicleData: vehicle,
                    statusOfRide: "accepted",
                    pickUpOtp: box.get("PickOtp")?.toString(),
                    bookingId: box.get("bookingId")?.toString(),
                    rideId: data is Map ? (data["rideId"]?.toString()) : null,
                    paymentUrl: box.get("payment_url")?.toString(),
                  ));
                } else if (state.status == "ongoing") {
                  goToWithReplacement(SendRideRequestScreen(
                    selectedVehicleData: vehicle,
                    statusOfRide: "ongoing",
                    pickUpOtp: box.get("PickOtp")?.toString(),
                    bookingId: box.get("bookingId")?.toString(),
                    rideId: data is Map ? (data["rideId"]?.toString()) : null,
                    paymentUrl: box.get("payment_url")?.toString(),
                  ));
                } else if (state.status == "completed" &&
                    state.paymentStatus == "collected") {
                  box.delete("ride_data");
                  goToWithReplacement(const ItemHomeScreen());
                } else if (state.status == "completed" &&
                    state.paymentStatus == "") {
                  goToWithReplacement(
                      RiderPaymentScreen(
                        bookingId: box.get("bookingId")?.toString() ?? "",
                        rideId: data is Map ? (data["rideId"]?.toString() ?? "") : "",
                        fare: vehicle["fare"] ?? 0,
                        paymentUrl: box.get("payment_url")?.toString() ?? "",
                      ));
                } else {
                  box.delete("ride_data");
                  box.delete("payment_url");
                  box.delete("PickOtp");
                  box.delete("bookingId");
                  box.delete("selected_vehicle");
                  goToWithReplacement(const ItemHomeScreen());
                }
              } catch (e) {
                box.delete("ride_data");
                box.delete("payment_url");
                box.delete("PickOtp");
                box.delete("bookingId");
                box.delete("selected_vehicle");
                goToWithReplacement(const ItemHomeScreen());
              }
            } else if (state is CheckRideFailed) {
              box.delete("ride_data");
              box.delete("payment_url");
              box.delete("PickOtp");
              box.delete("bookingId");
              box.delete("selected_vehicle");

              goToWithReplacement(const ItemHomeScreen());
            }
          },
          child: const SplashScreen()),
    );
  }
}
