import 'package:flutter/material.dart';

import 'order_model.dart';

/// The signed-in PetHub user.
@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl = '',
    this.city = '',
    this.bio = '',
    this.joinedAt,
    this.isVerified = false,
    this.sellerRating = 4.9,
    this.sellerSales = 12,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;
  final String city;
  final String bio;
  final DateTime? joinedAt;
  final bool isVerified;
  final double sellerRating;
  final int sellerSales;

  String get firstName => fullName.split(' ').first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? city,
    String? bio,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      joinedAt: joinedAt,
      isVerified: isVerified,
      sellerRating: sellerRating,
      sellerSales: sellerSales,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'city': city,
    'bio': bio,
    'joinedAt': joinedAt?.toIso8601String(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? '',
    fullName: json['fullName'] as String? ?? 'Pet Lover',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String? ?? '',
    city: json['city'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
  );
}

/// A review left by a buyer or for a product.
@immutable
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.author,
    required this.avatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.petId,
    this.productId,
  });

  final String id;
  final String author;
  final String avatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? petId;
  final String? productId;
}

/// A pet purchase enquiry / adoption enquiry.
@immutable
class PetInquiry {
  const PetInquiry({
    required this.id,
    required this.petId,
    required this.petName,
    required this.sellerId,
    required this.sellerName,
    required this.buyerId,
    required this.sellerRole,
    required this.createdAt,
    this.message = '',
    this.status = PetInquiryStatus.sent,
  });

  final String id;
  final String petId;
  final String petName;
  final String sellerId;
  final String sellerName;
  final String buyerId;
  final String sellerRole;
  final DateTime createdAt;
  final String message;
  final PetInquiryStatus status;

  PetInquiry copyWith({PetInquiryStatus? status, String? message}) =>
      PetInquiry(
        id: id,
        petId: petId,
        petName: petName,
        sellerId: sellerId,
        sellerName: sellerName,
        buyerId: buyerId,
        sellerRole: sellerRole,
        createdAt: createdAt,
        message: message ?? this.message,
        status: status ?? this.status,
      );
}

enum PetInquiryStatus { sent, read, replied, closed }

extension PetInquiryStatusX on PetInquiryStatus {
  String get label => switch (this) {
    PetInquiryStatus.sent => 'Sent',
    PetInquiryStatus.read => 'Viewed',
    PetInquiryStatus.replied => 'Replied',
    PetInquiryStatus.closed => 'Closed',
  };
}

/// A pet purchase — a confirmed sale that appears in order history.
@immutable
class PetPurchase {
  const PetPurchase({
    required this.id,
    required this.petId,
    required this.petName,
    required this.petImage,
    required this.sellerName,
    required this.amount,
    required this.purchasedAt,
    this.status = OrderStatus.placed,
  });

  final String id;
  final String petId;
  final String petName;
  final String petImage;
  final String sellerName;
  final double amount;
  final DateTime purchasedAt;
  final OrderStatus status;

  PetPurchase copyWith({OrderStatus? status}) => PetPurchase(
    id: id,
    petId: petId,
    petName: petName,
    petImage: petImage,
    sellerName: sellerName,
    amount: amount,
    purchasedAt: purchasedAt,
    status: status ?? this.status,
  );
}
