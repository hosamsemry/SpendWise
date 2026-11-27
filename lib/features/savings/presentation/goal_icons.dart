import 'package:flutter/material.dart';

/// Icons a goal can use, by the key stored in `savings_goals.icon`.
const Map<String, IconData> goalIcons = {
  'savings': Icons.savings_rounded,
  'emergency': Icons.shield_rounded,
  'gift': Icons.card_giftcard_rounded,
  'car': Icons.directions_car_rounded,
  'home': Icons.home_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'school': Icons.school_rounded,
  'wedding': Icons.favorite_rounded,
  'phone': Icons.smartphone_rounded,
  'health': Icons.medical_services_rounded,
};

IconData goalIconFor(String? key) => goalIcons[key] ?? Icons.savings_rounded;
