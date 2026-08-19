// ignore: file_names
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/account/profile_screen.dart';
import 'package:ride_on/presentation/screens/account/share_app_screen.dart';
import 'package:ride_on/presentation/screens/account/setting_screen.dart';
import 'package:ride_on/presentation/screens/account/static_screen.dart';
import 'package:ride_on/presentation/screens/account/wallet_screen.dart';
import 'package:ride_on/presentation/screens/auth/login_screen.dart';

import '../../core/utils/common_widget.dart';
import '../../core/utils/theme/project_color.dart';
import '../../core/utils/theme/theme_style.dart';
import '../cubits/book_ride_cubit.dart';
import '../cubits/history/history_cubit.dart';
import '../cubits/logout_cubit.dart';
import '../cubits/profile/edit_profile_cubit.dart';
import '../cubits/realtime/update_ride_request_parameter.dart';

import '../screens/history/history_screen.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  @override
  void initState() {
    context.read<MyImageCubit>().updateMyImage(myImage);
    context
        .read<BookRideRealTimeDataBaseCubit>()
        .updateUserImageUrl(userImageUrl: myImage);
    context.read<UpdateRideRequestParameterCubit>().updateFirebaseUserParameter(
        rideId: context.read<BookRideRealTimeDataBaseCubit>().state.rideId,
        userParameter: {"userImageUrl": myImage});
    context.read<NameCubit>().updateName(loginModel?.data?.firstName ?? "");
    final rawEmail = loginModel?.data?.email ?? "";
    final cleanEmail = (rawEmail.contains("foxrun.com") || rawEmail.toLowerCase().startsWith("rider_")) ? "" : rawEmail;
    context.read<EmailCubit>().updateEmail(cleanEmail);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final historyCubit = context.read<HistoryCubit>();
      if (historyCubit.cachedBookings.isEmpty && historyCubit.state is! HistoryLoading) {
        historyCubit.getHistoryData(
            context: context,
            bookingKeyMap: {"booking_status": "Completed", "offset": "0"});
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        right: Radius.circular(40),
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    CustomRowItem(
                      imagePath: "assets/images/history_image.svg",
                      title: "History".translate(context),
                      subtitle: "Your past rides".translate(context),
                      iconBgColor: const Color(0xFFFFF4E5), // Light orange
                      iconColor: const Color(0xFFF9A825),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HistoryScreen()));
                      },
                    ),
                    _buildDivider(),
                    CustomRowItem(
                      imagePath: "assets/images/Wallet.svg",
                      title: "Wallet".translate(context),
                      subtitle: "Balance, payments & more".translate(context),
                      iconBgColor: const Color(0xFFF5F5F5), // Light grey
                      iconColor: Colors.black87,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    CustomRowItem(
                      imagePath: "assets/images/Settings.svg",
                      title: "Settings".translate(context),
                      subtitle: "Manage your preferences".translate(context),
                      iconBgColor: const Color(0xFFF5F5F5),
                      iconColor: Colors.black87,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingScreen()));
                      },
                    ),
                    _buildDivider(),
                    CustomRowItem(
                      imagePath: "assets/images/Help and Support.svg",
                      title: "Help & Support".translate(context),
                      subtitle: "Get help, raise a ticket".translate(context),
                      iconBgColor: const Color(0xFFF5F5F5),
                      iconColor: Colors.black87,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const StaticScreen(
                                      data: "Help and Support",
                                      isBack: true,
                                    )));
                      },
                    ),
                    _buildDivider(),
                    CustomRowItem(
                      imagePath: "assets/images/About Us.svg",
                      title: "About Us".translate(context),
                      subtitle: "Know more about us".translate(context),
                      iconBgColor: const Color(0xFFF5F5F5),
                      iconColor: Colors.black87,
                      onTap: () {
                        Navigator.of(context).pop();
                        goTo(const StaticScreen(
                          data: "About Us",
                          isBack: true,
                        ));
                      },
                    ),
                    _buildDivider(),
                    CustomRowItem(
                      imagePath: "assets/images/Share.svg",
                      title: "Share".translate(context),
                      subtitle: "Invite your friends".translate(context),
                      iconBgColor: const Color(0xFFFFF4E5),
                      iconColor: Colors.black87,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ShareAppScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    BlocConsumer<LogoutCubit, LogoutState>(
                      listener: (context, state) {
                        if (state is LogoutFailure) {
                          showErrorToastMessage("Logout Failed: ${state.error}");
                        } else if (state is LogoutSuccess) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      builder: (context, state) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          child: InkWell(
                            onTap: () {
                              showDynamicBottomSheets(context,
                                  title: "Logout".translate(context),
                                  description: "Are you sure You Want to Logout?".translate(context),
                                  firstButtontxt: "Cancel".translate(context),
                                  secondButtontxt: "Yes".translate(context),
                                  onpressed: () {
                                    Navigator.pop(context);
                                  }, onpressed1: () async {
                                    token = "";
                                    context.read<LogoutCubit>().logout(context);
                                  });
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF5F5), // Soft red
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Logout".translate(context),
                                          style: headingBlack(context).copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Log out from your account".translate(context),
                                          style: heading3Grey1(context).copyWith(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 80, right: 20),
      child: Divider(
        color: Colors.grey.shade100,
        height: 1,
        thickness: 1,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF8E1), // Very light amber
            Colors.white,
          ],
        ),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 15, right: 15, bottom: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87, size: 20),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 25),
              // Profile info
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      goTo(const EditProfile());
                    },
                    child: BlocBuilder<MyImageCubit, dynamic>(
                      builder: (context, state) {
                        return myImage.isEmpty
                            ? Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFF9A825), width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 38,
                                    color: Color(0xFFF9A825),
                                  ),
                                ),
                              )
                            : Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFF9A825), width: 1.5),
                                ),
                                child: ClipOval(
                                  child: myNetworkImage(
                                      context.read<MyImageCubit>().state),
                                ),
                              );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlocBuilder<NameCubit, dynamic>(
                          builder: (context, state) {
                            return Text(
                              context.read<NameCubit>().state,
                              style: headingBlack(context).copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        BlocBuilder<EmailCubit, dynamic>(
                          builder: (context, state) {
                            final emailText = context.read<EmailCubit>().state;
                            if (emailText.isEmpty || emailText.contains("foxrun.com") || emailText.toLowerCase().startsWith("rider_")) {
                              final mobile = loginModel?.data?.phone ?? "";
                              final code = loginModel?.data?.phoneCountry ?? "";
                              final phoneStr = "$code $mobile".trim();
                              if (phoneStr.isNotEmpty) {
                                return Text(
                                  phoneStr,
                                  style: heading3Grey1(context).copyWith(fontSize: 13),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            return Text(
                              emailText,
                              style: heading3Grey1(context).copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Rating and Rides pill
                        BlocBuilder<HistoryCubit, HistoryState>(
                          builder: (context, state) {
                            final historyCubit = context.read<HistoryCubit>();
                            final bookingsList = (state is HistorySuccess && state.bookings != null)
                                ? state.bookings!
                                : historyCubit.cachedBookings;
                            final count = bookingsList.length;

                            String rating = "5.0";

                            final rawRating = loginModel?.data?.userRating;
                            if (rawRating != null && rawRating.isNotEmpty && rawRating != "0" && rawRating != "0.0") {
                              final parsed = double.tryParse(rawRating);
                              if (parsed != null && parsed > 0) {
                                rating = parsed.toStringAsFixed(1);
                              }
                            }

                            if (rating == "5.0" && bookingsList.isNotEmpty) {
                              double sum = 0;
                              int validRatings = 0;
                              for (var b in bookingsList) {
                                final r = b.rating ?? b.reviewRating;
                                if (r != null && r.isNotEmpty) {
                                  final val = double.tryParse(r);
                                  if (val != null && val > 0) {
                                    sum += val;
                                    validRatings++;
                                  }
                                }
                              }
                              if (validRatings > 0) {
                                rating = (sum / validRatings).toStringAsFixed(1);
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Color(0xFFF9A825), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: headingBlack(context).copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(width: 1, height: 10, color: Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  (state is HistoryLoading && bookingsList.isEmpty)
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: Color(0xFFF9A825),
                                          ),
                                        )
                                      : Text(
                                          "$count Rides",
                                          style: heading3Grey1(context).copyWith(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomRowItem extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const CustomRowItem({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.iconBgColor,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  imagePath,
                  width: 20,
                  height: 20,
                  colorFilter: iconColor != null
                      ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: headingBlack(context).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: heading3Grey1(context).copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
