class CouponResponse {
  int? status;
  String? message;
  CouponData? data;
  String? error;

  CouponResponse({this.status, this.message, this.data, this.error});

  CouponResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? CouponData.fromJson(json['data']) : null;
    error = json['error'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {};
    map['status'] = status;
    map['message'] = message;
    if (data != null) map['data'] = data!.toJson();
    map['error'] = error;
    return map;
  }
}

class CouponData {
  Coupon? coupon;

  CouponData({this.coupon});

  CouponData.fromJson(Map<String, dynamic> json) {
    coupon = json['coupon'] != null ? Coupon.fromJson(json['coupon']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {};
    if (coupon != null) {
      map['coupon'] = coupon!.toJson();
    }
    return map;
  }
}

class Coupon {
  int? id;
  String? couponTitle;
  String? couponSubtitle;
  String? couponCode;
  String? couponExpiryDate;
  String? couponType;
  String? couponValue;
  String? minOrderAmount;
  String? couponDescription;
  String? status;
  int? maxUses;
  int? maxUsesPerUser;
  int? usedCount;
  bool? isFirstBooking;
  String? createdAt;
  String? updatedAt;

  Coupon({
    this.id,
    this.couponTitle,
    this.couponSubtitle,
    this.couponCode,
    this.couponExpiryDate,
    this.couponType,
    this.couponValue,
    this.minOrderAmount,
    this.couponDescription,
    this.status,
    this.maxUses,
    this.maxUsesPerUser,
    this.usedCount,
    this.isFirstBooking,
    this.createdAt,
    this.updatedAt,
  });

  Coupon.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    couponTitle = json['coupon_title'];
    couponSubtitle = json['coupon_subtitle'];
    couponCode = json['coupon_code'];
    couponExpiryDate = json['coupon_expiry_date'];
    couponType = json['coupon_type'];
    couponValue = json['coupon_value'];
    minOrderAmount = json['min_order_amount'];
    couponDescription = json['coupon_description'];
    status = json['status'];
    maxUses = json['max_uses'];
    maxUsesPerUser = json['max_uses_per_user'];
    usedCount = json['used_count'];
    isFirstBooking = json['is_first_booking'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {};
    map['id'] = id;
    map['coupon_title'] = couponTitle;
    map['coupon_subtitle'] = couponSubtitle;
    map['coupon_code'] = couponCode;
    map['coupon_expiry_date'] = couponExpiryDate;
    map['coupon_type'] = couponType;
    map['coupon_value'] = couponValue;
    map['min_order_amount'] = minOrderAmount;
    map['coupon_description'] = couponDescription;
    map['status'] = status;
    map['max_uses'] = maxUses;
    map['max_uses_per_user'] = maxUsesPerUser;
    map['used_count'] = usedCount;
    map['is_first_booking'] = isFirstBooking;
    map['created_at'] = createdAt;
    map['updated_at'] = updatedAt;
    return map;
  }
}
