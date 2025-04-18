import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _pricePerKmKey = 'price_per_km';
  static const double _defaultPricePerKm = 0.5;

  Future<double> getPricePerKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_pricePerKmKey) ?? _defaultPricePerKm;
  }

  Future<void> setPricePerKm(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pricePerKmKey, price);
  }
} 