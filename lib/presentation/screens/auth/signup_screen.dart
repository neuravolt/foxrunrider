import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
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

  bool isChecked = false;
  String selectedCountryCode = "+91";
  String defaultCountry = "IN";

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    context.read<SetCountryCubit>().reset();
    super.initState();
    isNumeric=false;
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);

    return PopScope(
      canPop: false,

      child: Scaffold(
          bottomSheet: isNumeric==true&& Platform.isIOS?KeyboardDoneButton(
            onTap: () {
              setState(() {
                isNumeric = false;
              });
            },
          ):null,
          resizeToAvoidBottomInset: false,
          backgroundColor: notifires.getbgcolor,
          body: MultiBlocListener(
              listeners: [
                BlocListener<UpdateProfileCubit, UpdateProfileState>(
                  listener: (context, state) {
                    if (state is UpdateProfileLoading) {
                      Widgets.showLoader(context);
                    } else if (state is UpdateProfileSuccess) {
                      Widgets.hideLoder(context);
                      context.read<NameCubit>().updateName(textEditingSignUpControllerFirstName.text);
                      context.read<EmailCubit>().updateEmail(textEditingSignUpControllerEmail.text);
                      if (loginModel?.data != null) {
                        loginModel!.data!.firstNameSetter = textEditingSignUpControllerFirstName.text;
                      }
                      showToastMessage("Profile saved successfully!".translate(context));
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const ItemHomeScreen()),
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
                                  countryCode:
                                      state.loginModel.data!.phoneCountry,
                                  otpValue: state.loginModel.data!.otpValue,
                                  email: "",
                                  defaultCountry:
                                      state.loginModel.data!.defaultCountry,
                                  changeMobile: false,
                                  loginWithSocialMedia: false,
                                  routeString: "SignUp",
                                )));
                  } else if (state is SignUpFailure) {
                    Widgets.hideLoder(context);
                    showErrorToastMessage(state.error);
                  }
                }),
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
              child: Stack(
                children: [
                  Positioned(
                      left: 0,
                      top: 0,
                      child: SvgPicture.asset("assets/images/EllipseTop.svg",)),

                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: Dimensions.containerWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeLarge,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 130),
                                  commonlyUserLogo(),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: "Complete ",
                                      style: heading1(context),
                                      children: [
                                        TextSpan(
                                          text: "Your Profile",
                                          style: heading1(context).copyWith(color: themeColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text.rich(
                                    TextSpan(
                                      text: "Create an account to ",
                                      style: regular2(context).copyWith(color: notifires.getGrey3whiteColor),
                                      children: [
                                        TextSpan(
                                          text: "continue.",
                                          style: regular2(context).copyWith(color: themeColor, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  TextFieldAdvance(
                                    onTap: (){
                                      isNumeric=false;
                                      setState(() {

                                      });
                                    },
                                    inputAlignment: TextAlign.start,
                                    txt: "Name".translate(context),
                                    icons: Icon(
                                      Icons.person_2_outlined,
                                      color: blackColor,
                                    ),
                                    textEditingControllerCommon:
                                        textEditingSignUpControllerFirstName,
                                    inputType: TextInputType.name,
                                    validator: (value) {
                                      if (isValidName(value!)) {
                                        return null;
                                      } else {
                                        return "Please enter the name"
                                            .translate(context);
                                      }
                                    },
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  BlocBuilder<SetCountryCubit, SetCountryState>(
                                      builder: (context, state) {
                                    return IntelPhoneFieldRefs(
                                      onTap: (){
                                        isNumeric=true;
                                        setState(() {

                                        });
                                      },
                                      key: ValueKey(state.countryCode),
                                      defultcountry: state.countryCode,
                                      textEditingControllerCommons:
                                          textEditingSingUpControllerPhoneNumber,
                                      oncountryChanged: (number) {
                                        context.read<SetCountryCubit>().reset();
                                        textEditingSingUpControllerPhoneNumber
                                            .clear();
                                        context
                                            .read<SetCountryCubit>()
                                            .setCountry(
                                                dialCode: number.dialCode,
                                                countryCode: number.code);
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
                                  }),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  TextFieldAdvance(
                                    onTap: (){
                                      isNumeric=false;
                                      setState(() {

                                      });
                                    },
                                    inputAlignment: TextAlign.start,
                                    txt: "Email".translate(context),
                                    icons: Icon(
                                      Icons.mail_outline_outlined,
                                      color: blackColor,
                                    ),
                                    textEditingControllerCommon:
                                        textEditingSignUpControllerEmail,
                                    inputType: TextInputType.emailAddress,
                                    validator: (value) {
                                      return validateEmail(value!, context);
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        constraints:
                                            const BoxConstraints.expand(
                                                width: 33, height: 40),
                                        color: Colors.transparent,
                                        padding:
                                            const EdgeInsets.only(right: 5),
                                        child: Transform.scale(
                                          scale: 1.2,
                                          child: Checkbox(
                                            activeColor: themeColor,
                                            focusColor: whiteColor,
                                            value: isChecked,
                                            onChanged: (bool? newValue) {
                                              setState(() {
                                                isChecked = newValue!;
                                              });
                                            },
                                            checkColor: whiteColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      Dimensions.radiusSmall),
                                            ),
                                            side: BorderSide(
                                                color: notifires
                                                    .getGrey3whiteColor,
                                                width: 2.0),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            showModalBottomSheet(
                                              useRootNavigator: true,
                                              backgroundColor: notifires.getbgcolor,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              context: context,
                                              builder: (BuildContext context) {

                                                return  const StaticScreen(
                                                    data: "Terms and Conditions");
                                              },
                                            );
                                          },
                                          child: Text.rich(TextSpan(
                                              text:
                                                  "By creating an account, you agree to our ".translate(context)+"\n"
                                                      .translate(context),
                                              style: regular3(context)
                                                  .copyWith(fontSize: 14),
                                              children: [
                                                TextSpan(
                                                    text:
                                                    "\n${"Terms and Condition"
                                                        .translate(context)}",
                                                    style: heading3Grey1(
                                                            context)
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight.w200,
                                                            color: themeColor,
                                                            fontSize: 14))
                                              ])),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 50),
                                   GestureDetector(
                                     onTap: () {
                                       if (_formKey.currentState!.validate()) {
                                         if (isChecked == false) {
                                           showErrorToastMessage(
                                               "Please select the terms and condition."
                                                   .translate(context));
                                           return;
                                         }
                                         if (token.isNotEmpty) {
                                           context.read<UpdateProfileCubit>().updateProfileMethod(
                                             postData: {
                                               "first_name": textEditingSignUpControllerFirstName.text,
                                               "email": textEditingSignUpControllerEmail.text,
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
                                         context
                                             .read<AuthSignUpCubit>()
                                             .signUp(
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
                                       padding: const EdgeInsets.symmetric(horizontal: 10),
                                       decoration: BoxDecoration(
                                         gradient: LinearGradient(
                                           colors: [
                                             themeColor.withValues(alpha: 0.85),
                                             themeColor,
                                             const Color(0xFFFFB300),
                                           ],
                                           begin: Alignment.centerLeft,
                                           end: Alignment.centerRight,
                                         ),
                                         borderRadius: BorderRadius.circular(30),
                                         boxShadow: [
                                           BoxShadow(
                                             color: themeColor.withValues(alpha: 0.35),
                                             blurRadius: 15,
                                             offset: const Offset(0, 6),
                                           ),
                                         ],
                                       ),
                                       child: Row(
                                         children: [
                                           Container(
                                             width: 40,
                                             height: 40,
                                             decoration: const BoxDecoration(
                                               color: Colors.white,
                                               shape: BoxShape.circle,
                                             ),
                                             child: const Icon(
                                               Icons.person_add_outlined,
                                               color: Colors.black87,
                                               size: 20,
                                             ),
                                           ),
                                           Expanded(
                                             child: Center(
                                               child: Text(
                                                 "Sign up".translate(context),
                                                 style: heading1(context).copyWith(
                                                   color: Colors.black,
                                                   fontSize: 18,
                                                   fontWeight: FontWeight.bold,
                                                 ),
                                               ),
                                             ),
                                           ),
                                           const Icon(
                                             Icons.auto_awesome,
                                             color: Colors.white,
                                             size: 16,
                                           ),
                                           const SizedBox(width: 8),
                                           Container(
                                             width: 40,
                                             height: 40,
                                             decoration: const BoxDecoration(
                                               color: Colors.white,
                                               shape: BoxShape.circle,
                                             ),
                                             child: const Icon(
                                               Icons.arrow_forward,
                                               color: Colors.black87,
                                               size: 20,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                   const SizedBox(height: 35),
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     crossAxisAlignment: CrossAxisAlignment.center,
                                     children: [
                                       Container(
                                         height: 1.5,
                                         width: MediaQuery.of(context).size.width * 0.12,
                                         color: notifires.getGrey4whiteColor,
                                       ),
                                       const SizedBox(width: 12),
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                         decoration: BoxDecoration(
                                           color: notifires.getbgcolor,
                                           borderRadius: BorderRadius.circular(20),
                                           border: Border.all(
                                             color: notifires.getGrey5whiteColor,
                                           ),
                                         ),
                                         child: Text(
                                           "or Sign up with".translate(context),
                                           style: regular3(context).copyWith(fontSize: 13),
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                       Container(
                                         height: 1.5,
                                         width: MediaQuery.of(context).size.width * 0.12,
                                         color: notifires.getGrey4whiteColor,
                                       ),
                                     ],
                                   ),
                                   const SizedBox(height: 20),
                                   Align(
                                     alignment: Alignment.center,
                                     child: Row(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: [
                                         InkWell(
                                           onTap: () {
                                             context.read<GoogleLoginCubit>().googleLogin(context);
                                           },
                                           child: Container(
                                             padding: const EdgeInsets.all(14),
                                             decoration: BoxDecoration(
                                               color: Colors.white,
                                               shape: BoxShape.circle,
                                               boxShadow: [
                                                 BoxShadow(
                                                   color: Colors.black.withValues(alpha: 0.06),
                                                   blurRadius: 12,
                                                   offset: const Offset(0, 4),
                                                 ),
                                               ],
                                             ),
                                             child: SvgPicture.asset("assets/images/google_icon.svg", width: 26, height: 26),
                                           ),
                                         ),
                                         if (Platform.isIOS) const SizedBox(width: 25),
                                         if (Platform.isIOS)
                                           InkWell(
                                             onTap: () {
                                               context.read<AppleLoginCubit>().appleLogin(context);
                                             },
                                             child: Container(
                                               padding: const EdgeInsets.all(14),
                                               decoration: BoxDecoration(
                                                 color: Colors.white,
                                                 shape: BoxShape.circle,
                                                 boxShadow: [
                                                   BoxShadow(
                                                     color: Colors.black.withValues(alpha: 0.06),
                                                     blurRadius: 12,
                                                     offset: const Offset(0, 4),
                                                   ),
                                                 ],
                                               ),
                                               child: SvgPicture.asset("assets/images/apple_icon.svg", width: 26, height: 26),
                                             ),
                                           ),
                                       ],
                                     ),
                                   ),
                                   const SizedBox(height: 35),
                                   GestureDetector(
                                     onTap: () {
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(
                                           builder: (context) => const LoginScreen(),
                                         ),
                                       );
                                     },
                                     child: Container(
                                       padding: const EdgeInsets.all(16),
                                       decoration: BoxDecoration(
                                         color: const Color(0xFFFFFDF7),
                                         borderRadius: BorderRadius.circular(20),
                                         border: Border.all(
                                           color: const Color(0xFFFFE8B3),
                                           width: 1.5,
                                         ),
                                         boxShadow: [
                                           BoxShadow(
                                             color: Colors.black.withValues(alpha: 0.04),
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
                                               borderRadius: BorderRadius.circular(16),
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
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 Text(
                                                   "Already have an account?".translate(context),
                                                   style: heading1(context).copyWith(
                                                     color: Colors.black,
                                                     fontSize: 15,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                                 const SizedBox(height: 2),
                                                 Text(
                                                   "Welcome back! Please sign in to continue.".translate(context),
                                                   style: regular3(context).copyWith(
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
                                   const SizedBox(height: 40),
                                ]),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 70,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        languageButton(
                          onTap: () {
                            goTo(const SelectLanguageScreen(isBack: true));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ))),
    );
   }
 }
