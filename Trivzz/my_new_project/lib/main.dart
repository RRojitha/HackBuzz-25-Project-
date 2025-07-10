import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF003366),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF003366),
          titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF003366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? predictionResult;
  final stt.SpeechToText _speech = stt.SpeechToText();
  File? _selectedImage;
  bool _isUploading = false;

  GoogleMapController? _mapController;
  static const LatLng _initialPosition = LatLng(28.7041, 77.1025); // Default to Delhi

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<List<Map<String, dynamic>>> _searchLocation(String query) async {
    final result = await ApiService.fetchLocation(query);
    return result != null ? [result] : [];
  }

  Future<void> _setGeometry(Map<String, dynamic> location) async {
    double lat = location["lat"];
    double lon = location["lon"];

    setState(() {
      predictionResult = {"status": "🔄 Analyzing Risk..."};
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lon), 12.0),
      );
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/predict'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"lat": lat, "lon": lon}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          predictionResult = {
            "🔥 Fire Risk": "${data['risk_level']}",
            "🌡️ Temperature": "${data['temperature'].toStringAsFixed(2)}°C",
            "💨 Wind Speed": "${data['wind_speed'].toStringAsFixed(2)} km/h",

          };
        });
      } else {
        setState(() {
          predictionResult = {"⚠️ Error": "Server responded with ${response.statusCode}"};
        });
      }
    } catch (e) {
      setState(() {
        predictionResult = {"❌ Error": "Failed to connect to server!"};
      });
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(
        onResult: (result) {
          setState(() {
            _searchController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _isUploading = true;
      });

      await _uploadImage(_selectedImage!);
    }
  }

  Future<void> _uploadImage(File image) async {
    setState(() {
      predictionResult = {"📡 Uploading": "Please wait..."};
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5000/predict'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = jsonDecode(await response.stream.bytesToString());
        setState(() {
          predictionResult = {
            "🌍 Disaster": responseData['disaster_type'],
            "🔥 Fire Risk": "${responseData['risk_level']}",
            "🌡️ Temperature": "${responseData['temperature'].toStringAsFixed(2)}°C",
            "💨 Wind Speed": "${responseData['wind_speed'].toStringAsFixed(2)} km/h",
          };
          _isUploading = false;
        });
      } else {
        setState(() {
          predictionResult = {"❌ Upload failed": "Server error"};
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        predictionResult = {"🚨 Error": "Connection to server failed!"};
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Disaster Prediction"),
        backgroundColor: Theme.of(context).primaryColor,
        leading: Icon(Icons.map, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TypeAheadField<Map<String, dynamic>>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.9),
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.mic, color: Colors.black54),
                        onPressed: _startListening,
                      ),
                      IconButton(
                        icon: Icon(Icons.image, color: Colors.black54),
                        onPressed: _pickImage,
                      ),
                    ],
                  ),
                  labelText: "Search location",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              suggestionsCallback: _searchLocation,
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion["name"]));
              },
              onSuggestionSelected: (suggestion) {
                _searchController.text = suggestion["name"];
                _setGeometry(suggestion);
              },
            ),
          ),

          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 5.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),

          if (predictionResult != null)
            Container(
              margin: EdgeInsets.all(10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF003366).withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: predictionResult!.entries.map((entry) {
                  return Text(
                    "${entry.key}: ${entry.value}",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),

          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
