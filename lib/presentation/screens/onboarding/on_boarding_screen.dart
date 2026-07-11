import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/auth/google_update_screen.dart';
import 'package:ride_on/presentation/screens/auth/signup_screen.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/language_select_screen.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/auth/apple_login_cubit.dart';
import '../../cubits/auth/google_login_cubit.dart';


class Onboardingscreen extends StatefulWidget {
  const Onboardingscreen({super.key});

  @override
  State<Onboardingscreen> createState() => _OnboardingscreenState();
}

class _OnboardingscreenState extends State<Onboardingscreen> {
  List content = [
    {
      "image": "assets/images/cuate.svg",
      "title": "More than just a ride, it's a vibe!",
      "description":
          "Book rides in seconds, track your arrival in real-time, and enjoy stress-free journeys. Choose from different ride options, all driven by professional and friendly drivers."
    },
  ];

  late PageController pageController;
  int currentIndex = 0;

  final List<String> _backgroundImages = [
    "assets/images/onboarding_bg1.png",
    "assets/images/onboarding_bg2.png",
    "assets/images/onboarding_bg3.png",
  ];

  Timer? _timer;
  int _currentBgIndex = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _backgroundImages.length;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (var imagePath in _backgroundImages) {
      precacheImage(AssetImage(imagePath), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    return Scaffold(
      backgroundColor: whiteColor,
      body: MultiBlocListener(
          listeners: [
            BlocListener<GoogleLoginCubit, GoogleLoginState>(
              listener: (context, state) {
                if (state is GoogleLoginSucess) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ItemHomeScreen()));
                } else if (state is AddPhoneNumberState) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GoogleUpdate(
                                email: state.loginModel.data?.email ?? "",
                              )));
                } else if (state is GoogleLoginFailure) {
                  showErrorToastMessage(state.error);
                }
              },
            ),
            BlocListener<AppleLoginCubit, AppleLoginState>(
              listener: (context, state) {
                if (state is AppleLoginSuccess) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ItemHomeScreen()));
                } else if (state is AddPhoneNumberAppleState) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GoogleUpdate()));
                } else if (state is AppleLoginFailure) {
                  closeLoading();
                  showErrorToastMessage(state.error);
                }
              },
            )
          ],

          child: SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1000),
                      child: Image.asset(
                        _backgroundImages[_currentBgIndex],
                        key: ValueKey<int>(_currentBgIndex),
                        fit: BoxFit.fill,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.74,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 60),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomsButtons(
                                textColor: blackColor,
                                text: "Proceed to Sign-Up",
                                backgroundColor: themeColor,
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SignUp()),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Or continue using".translate(context),
                                style: regular(context),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      context.read<GoogleLoginCubit>().googleLogin(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: .3),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: SvgPicture.asset("assets/images/google_icon.svg"),
                                    ),
                                  ),
                                  if (Platform.isIOS) const SizedBox(width: 25),
                                  if (Platform.isIOS)
                                    InkWell(
                                      onTap: () {
                                        context.read<AppleLoginCubit>().appleLogin(context);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(alpha: .3),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: SvgPicture.asset("assets/images/apple_icon.svg"),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 70,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        languageButton(
                          onTap: () {
                            goTo(const SelectLanguageScreen(
                              isBack: true,
                            ));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )

      ),
    );
  }
}

Widget customOnboardingWidget(String image, String title, String description) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: SvgPicture.asset(image),
        ),
        const SizedBox(
          height: 20,
        ),
        Flexible(
          child: Text(
            title,
            textAlign: TextAlign.start,
            style: largeHeadingMedium.copyWith(fontSize: 24),
            softWrap: true,
          ),
        ),
        const SizedBox(
          height: 15,
        ),
        Text(
          description,
          style: smallHeadingMedium.copyWith(
              color: notifires.getGrey2whiteColor, fontSize: 14),
          textAlign: TextAlign.start,
        )
      ],
    ),
  );
}
