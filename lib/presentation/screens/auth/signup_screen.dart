import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/core/services/data_store.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/account/static_screen.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/language_select_screen.dart';
import '../../../core/extensions/workspace.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/auth/apple_login_cubit.dart';
import '../../cubits/auth/google_login_cubit.dart';
import '../../cubits/auth/signup_cubit.dart';
import '../../cubits/auth/user_authenticate_cubit.dart';
import '../../cubits/profile/edit_profile_cubit.dart';
import '../../widgets/custom_text_form_field.dart';
import '../../widgets/form_validations.dart';
import 'google_update_screen.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  TextEditingController textEditingSignUpControllerFirstName =
      TextEditingController();
  TextEditingController textEditingSignUpControllerEmail =
      TextEditingController();
  TextEditingController textEditingSingUpControllerlastName =
      TextEditingController();
  TextEditingController textEditingSingUpControllerPhoneNumber =
      TextEditingController();
  TextEditingController textEditingSignUpControllerPassword =
      TextEditingController();

  bool isChecked = true;
  String selectedCountryCode = "+91";
  String defaultCountry = "IN";

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    context.read<SetCountryCubit>().reset();
    super.initState();
    isNumeric = false;

    // Pre-fill fields if user is already logged in (completing profile)
    if (token.isNotEmpty && loginModel?.data != null) {
      final existingName = loginModel!.data!.firstName ?? '';
      if (existingName.isNotEmpty && existingName.toLowerCase() != "rider") {
        textEditingSignUpControllerFirstName.text = existingName;
      }
      final existingEmail = loginModel!.data!.email ?? '';
      if (existingEmail.isNotEmpty &&
          !existingEmail.contains("foxrun.com") &&
          !existingEmail.toLowerCase().startsWith("rider_")) {
        textEditingSignUpControllerEmail.text = existingEmail;
      }
      if ((loginModel!.data!.phone ?? '').isNotEmpty) {
        textEditingSingUpControllerPhoneNumber.text = loginModel!.data!.phone!;
      }
    }
  }

  @override
  void dispose() {
    textEditingSignUpControllerFirstName.dispose();
    textEditingSignUpControllerEmail.dispose();
    textEditingSingUpControllerlastName.dispose();
    textEditingSingUpControllerPhoneNumber.dispose();
    textEditingSignUpControllerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    final bool isCompletingProfile = token.isNotEmpty;

    return PopScope(
      canPop: isCompletingProfile,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF7),
        bottomSheet: isNumeric == true && Platform.isIOS
            ? KeyboardDoneButton(
                onTap: () {
                  setState(() {
                    isNumeric = false;
                  });
                },
              )
            : null,
        resizeToAvoidBottomInset: true,
        body: MultiBlocListener(
          listeners: [
            BlocListener<UpdateProfileCubit, UpdateProfileState>(
              listener: (context, state) {
                if (state is UpdateProfileLoading) {
                  Widgets.showLoader(context);
                } else if (state is UpdateProfileSuccess) {
                  Widgets.hideLoder(context);
                  if (state.loginModel.data != null) {
                    loginModel = state.loginModel;
                  } else if (loginModel?.data != null) {
                    loginModel!.data!.firstNameSetter =
                        textEditingSignUpControllerFirstName.text;
                    loginModel!.data!.emailSetter =
                        textEditingSignUpControllerEmail.text;
                  }

                  if (loginModel != null) {
                    UserData userObj = UserData();
                    userObj.saveLoginData(
                        "UserData", jsonEncode(loginModel!.toJson()));
                  }

                  context
                      .read<NameCubit>()
                      .updateName(textEditingSignUpControllerFirstName.text);
                  context
                      .read<EmailCubit>()
                      .updateEmail(textEditingSignUpControllerEmail.text);
                  context.read<UpdateProfileCubit>().clear();

                  showToastMessage(
                      "Profile saved successfully!".translate(context));
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ItemHomeScreen()),
                    (route) => false,
                  );
                } else if (state is UpdateProfileFailed) {
                  Widgets.hideLoder(context);
                  showErrorToastMessage(state.error);
                }
              },
            ),
            BlocListener<AuthSignUpCubit, AuthSignUpState>(
              listener: (context, state) {
                if (state is SignUpLoading) {
                  Widgets.showLoader(context);
                } else if (state is SignUpSuccess) {
                  Widgets.hideLoder(context);
                  context.read<AuthSignUpCubit>().resetState();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtpScreen(
                        number: state.loginModel.data!.phone,
                        countryCode: state.loginModel.data!.phoneCountry,
                        otpValue: state.loginModel.data!.otpValue,
                        email: "",
                        defaultCountry: state.loginModel.data!.defaultCountry,
                        changeMobile: false,
                        loginWithSocialMedia: false,
                        routeString: "SignUp",
                      ),
                    ),
                  );
                } else if (state is SignUpFailure) {
                  Widgets.hideLoder(context);
                  showErrorToastMessage(state.error);
                }
              },
            ),
            BlocListener<GoogleLoginCubit, GoogleLoginState>(
              listener: (context, state) {
                if (state is GoogleLoginSucess) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ItemHomeScreen(),
                    ),
                  );
                } else if (state is AddPhoneNumberState) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoogleUpdate(
                        email: state.loginModel.data?.email ?? "",
                      ),
                    ),
                  );
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
                      builder: (context) => const ItemHomeScreen(),
                    ),
                  );
                } else if (state is AddPhoneNumberAppleState) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoogleUpdate(),
                    ),
                  );
                } else if (state is AppleLoginFailure) {
                  closeLoading();
                  showErrorToastMessage(state.error);
                }
              },
            ),
          ],
          child: Stack(
            children: [
              // Background Gradient & Radial Glow
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFDF5),
                        Color(0xFFFFF9EB),
                        Color(0xFFFFFFFF),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFEBAA).withValues(alpha: 0.5),
                        const Color(0xFFFFF9EB).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8),

                                // Top Navigation Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (isCompletingProfile &&
                                        Navigator.canPop(context))
                                      IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          color: Color(0xFF1A1A1A),
                                          size: 20,
                                        ),
                                      )
                                    else
                                      Text(
                                        "foxrun",
                                        style: heading1(context).copyWith(
                                          color: const Color(0xFF1A1A1A),
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.8,
                                        ),
                                      ),

                                    // Language Pill Button
                                    InkWell(
                                      onTap: () {
                                        goTo(const SelectLanguageScreen(
                                            isBack: true));
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFFF2EAD6),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.language_rounded,
                                              size: 16,
                                              color: Color(0xFFE5A000),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "EN",
                                              style: regular2(context).copyWith(
                                                color: const Color(0xFF2C3E50),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: Color(0xFF7F8C8D),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Center Foxrun Logo Icon
                                commonlyUserLogo(),

                                const SizedBox(height: 16),

                                // Headline Title
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text: "Complete ".translate(context),
                                    style: heading1(context).copyWith(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E1E1E),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: "Your Profile".translate(context),
                                        style: heading1(context).copyWith(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  isCompletingProfile
                                      ? "Enter your name and email to save your profile"
                                          .translate(context)
                                      : "Create an account to continue"
                                          .translate(context),
                                  style: regular2(context).copyWith(
                                    color: const Color(0xFF718096),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 28),

                                // Name Input Field
                                TextFieldAdvance(
                                  onTap: () {
                                    isNumeric = false;
                                    setState(() {});
                                  },
                                  inputAlignment: TextAlign.start,
                                  txt: "Name".translate(context),
                                  icons: const Icon(
                                    Icons.person_2_outlined,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                  textEditingControllerCommon:
                                      textEditingSignUpControllerFirstName,
                                  inputType: TextInputType.name,
                                  validator: (value) {
                                    if (isValidName(value!)) {
                                      return null;
                                    } else {
                                      return "Please enter your name"
                                          .translate(context);
                                    }
                                  },
                                ),

                                const SizedBox(height: 18),

                                // Phone Field (ReadOnly display if logged in, interactive if signing up)
                                if (isCompletingProfile &&
                                    (loginModel?.data?.phone ?? '')
                                        .isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAF5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_outlined,
                                          color: Color(0xFF10B981),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "${loginModel?.data?.phoneCountry ?? '+91'} ${loginModel?.data?.phone}",
                                          style: regular2(context).copyWith(
                                            color: const Color(0xFF1E293B),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD1FAE5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                color: Color(0xFF10B981),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Verified",
                                                style: regular3(context)
                                                    .copyWith(
                                                  color: const Color(0xFF047857),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  BlocBuilder<SetCountryCubit, SetCountryState>(
                                    builder: (context, state) {
                                      return IntelPhoneFieldRefs(
                                        onTap: () {
                                          isNumeric = true;
                                          setState(() {});
                                        },
                                        key: ValueKey(state.countryCode),
                                        defultcountry: state.countryCode,
                                        textEditingControllerCommons:
                                            textEditingSingUpControllerPhoneNumber,
                                        oncountryChanged: (number) {
                                          context
                                              .read<SetCountryCubit>()
                                              .reset();
                                          textEditingSingUpControllerPhoneNumber
                                              .clear();
                                          context
                                              .read<SetCountryCubit>()
                                              .setCountry(
                                                dialCode: number.dialCode,
                                                countryCode: number.code,
                                              );
                                        },
                                        validator: (phoneNumber) {
                                          if (phoneNumber == null ||
                                              phoneNumber.number.isEmpty) {
                                            return "Please enter your phone number"
                                                .translate(context);
                                          }
                                          int expectedLength = phoneLengths[
                                                  phoneNumber.countryISOCode] ??
                                              10;
                                          if (phoneNumber.number.length !=
                                              expectedLength) {
                                            return "${"Phone number must be".translate(context)} $expectedLength ${"digits".translate(context)}";
                                          }
                                          return null;
                                        },
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 18),

                                // Email Input Field
                                TextFieldAdvance(
                                  onTap: () {
                                    isNumeric = false;
                                    setState(() {});
                                  },
                                  inputAlignment: TextAlign.start,
                                  txt: "Johnsmith@gmail.com",
                                  icons: const Icon(
                                    Icons.mail_outline_outlined,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                  textEditingControllerCommon:
                                      textEditingSignUpControllerEmail,
                                  inputType: TextInputType.emailAddress,
                                  validator: (value) {
                                    return validateEmail(value!, context);
                                  },
                                ),

                                const SizedBox(height: 20),

                                // Terms Checkbox Card
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Checkbox(
                                        activeColor: const Color(0xFFF59E0B),
                                        value: isChecked,
                                        onChanged: (bool? newValue) {
                                          setState(() {
                                            isChecked = newValue ?? true;
                                          });
                                        },
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          showModalBottomSheet(
                                            useRootNavigator: true,
                                            backgroundColor:
                                                notifires.getbgcolor,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            context: context,
                                            builder: (BuildContext context) {
                                              return const StaticScreen(
                                                data: "Terms and Conditions",
                                              );
                                            },
                                          );
                                        },
                                        child: Text.rich(
                                          TextSpan(
                                            text:
                                                "By continuing, you agree to our "
                                                    .translate(context),
                                            style: regular3(context).copyWith(
                                              fontSize: 12.5,
                                              color: const Color(0xFF64748B),
                                              height: 1.4,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: "Terms & Conditions"
                                                    .translate(context),
                                                style:
                                                    regular3(context).copyWith(
                                                  color:
                                                      const Color(0xFFD98A00),
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration
                                                      .underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                // Full-Width Gradient Action Button
                                GestureDetector(
                                  onTap: () {
                                    if (_formKey.currentState!.validate()) {
                                      if (!isChecked) {
                                        showErrorToastMessage(
                                            "Please select the terms and conditions."
                                                .translate(context));
                                        return;
                                      }

                                      if (isCompletingProfile) {
                                        context
                                            .read<UpdateProfileCubit>()
                                            .updateProfileMethod(
                                          postData: {
                                            "first_name":
                                                textEditingSignUpControllerFirstName
                                                    .text,
                                            "email":
                                                textEditingSignUpControllerEmail
                                                    .text,
                                          },
                                        );
                                        return;
                                      }

                                      if (textEditingSingUpControllerPhoneNumber
                                          .text.isEmpty) {
                                        showErrorToastMessage(
                                            "Fill valid mobile number"
                                                .translate(context));
                                        return;
                                      }

                                      context.read<AuthSignUpCubit>().signUp(
                                            context: context,
                                            name:
                                                textEditingSignUpControllerFirstName
                                                    .text,
                                            phoneCountry: context
                                                    .read<SetCountryCubit>()
                                                    .state
                                                    .dialCode
                                                    .startsWith("+")
                                                ? context
                                                    .read<SetCountryCubit>()
                                                    .state
                                                    .dialCode
                                                : "+${context.read<SetCountryCubit>().state.dialCode}",
                                            defaultCountry: context
                                                .read<SetCountryCubit>()
                                                .state
                                                .countryCode,
                                            phoneNumber:
                                                textEditingSingUpControllerPhoneNumber
                                                    .text,
                                            email:
                                                textEditingSignUpControllerEmail
                                                    .text,
                                          );
                                    }
                                  },
                                  child: Container(
                                    height: 56,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFC533),
                                          Color(0xFFFF9F0A),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF9F0A)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          isCompletingProfile
                                              ? "Save Profile".translate(context)
                                              : "Sign up".translate(context),
                                          style: heading1(context).copyWith(
                                            color: const Color(0xFF1E1E1E),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Positioned(
                                          right: 20,
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFF1E1E1E),
                                            size: 22,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Show Social Login Options ONLY if NOT already logged in
                                if (!isCompletingProfile) ...[
                                  const SizedBox(height: 35),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 1.5,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.12,
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          "or Sign up with".translate(context),
                                          style: regular3(context)
                                              .copyWith(fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        height: 1.5,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.12,
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          context
                                              .read<GoogleLoginCubit>()
                                              .googleLogin(context);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.06),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: SvgPicture.asset(
                                              "assets/images/google_icon.svg",
                                              width: 26,
                                              height: 26),
                                        ),
                                      ),
                                      if (Platform.isIOS)
                                        const SizedBox(width: 25),
                                      if (Platform.isIOS)
                                        InkWell(
                                          onTap: () {
                                            context
                                                .read<AppleLoginCubit>()
                                                .appleLogin(context);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.06),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.asset(
                                                "assets/images/apple_icon.svg",
                                                width: 26,
                                                height: 26),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 35),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFDF7),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFFFE8B3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.04),
                                            blurRadius: 15,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF3D6),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: const Icon(
                                              Icons.shield_outlined,
                                              color: Color(0xFFE6A100),
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Already have an account?"
                                                      .translate(context),
                                                  style:
                                                      heading1(context).copyWith(
                                                    color: Colors.black,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "Welcome back! Please sign in to continue."
                                                      .translate(context),
                                                  style: regular3(context)
                                                      .copyWith(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFFFD54F),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward,
                                              color: Colors.black87,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
