import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String apiKey = '882c7ba9bc4358298d4e08b801b60416';
  static const String baseUrl = 'http://api.openweathermap.org/geo/1.0/direct';

  static Future<Map<String, dynamic>?> fetchLocation(String query) async {
    final url = Uri.parse('$baseUrl?q=$query&limit=1&appid=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final location = data[0];
        return {
          "lat": location["lat"],
          "lon": location["lon"],
          "name": location["name"]
        };
      }
    }
    return null;
  }
}
