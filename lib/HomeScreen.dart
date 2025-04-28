import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'result_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;
  String _description = "";
  String _labelResult = "";
  File _imageFile = File('');
  late List<String> _labels;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadLabels();
    _loadModel();
  }
  Future<void> _checkPermissions() async {
    // Demander la permission pour la caméra
    PermissionStatus cameraStatus = await Permission.camera.request();

    // Demander la permission pour la galerie
    PermissionStatus galleryStatus = await Permission.photos.request();

    if (cameraStatus.isPermanentlyDenied) {
      _showPermissionSettingsDialog('Caméra', 'Nous avons besoin de la caméra pour prendre des photos. Veuillez autoriser cette permission dans les paramètres.');
    }

    if (galleryStatus.isPermanentlyDenied) {
      _showPermissionSettingsDialog('Galerie', 'Nous avons besoin d\'accéder à votre galerie pour importer des photos. Veuillez autoriser cette permission dans les paramètres.');
    }
  }

  void _showPermissionSettingsDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                openAppSettings(); // Ouvre les paramètres de l'application
                Navigator.pop(context); // Fermer la boîte de dialogue
              },
              child: Text("Paramètres"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Fermer la boîte de dialogue
              },
              child: Text("Annuler"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _loadLabels() async {
    final labelsData = await DefaultAssetBundle.of(context).loadString('assets/labels.txt');
    _labels = labelsData.split('\n').map((e) => e.trim()).toList();
  }
  // Charger le modèle TFLite
  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/mobilenetv2.tflite');
    setState(() {
      _isModelLoaded = true;
    });
  }

  // Sélectionner une image
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _imageFile = File(pickedFile.path);
    });

    _classifyImage(_imageFile);
  }

  // Prétraitement et classification de l'image
  Future<void> _classifyImage(File imageFile) async {
    img.Image image = img.decodeImage(imageFile.readAsBytesSync())!;
    img.Image resized = img.copyResize(image, width: 224, height: 224);

    var input = Float32List(1 * 224 * 224 * 3);
    int index = 0;

    for (int j = 0; j < 224; j++) {
      for (int k = 0; k < 224; k++) {
        final pixel = resized.getPixelSafe(k, j);
        input[index++] = (pixel.r / 127.5) - 1.0;
        input[index++] = (pixel.g / 127.5) - 1.0;
        input[index++] = (pixel.b / 127.5) - 1.0;
      }
    }

    var reshapedInput = input.reshape([1, 224, 224, 3]);
    var output = Float32List(1 * 1000).reshape([1, 1000]);

    // Exécuter l'inférence
    _interpreter.run(reshapedInput, output);

    int predictedIndex = output[0].indexWhere((e) => e == output[0].reduce((double a, double b) => a > b ? a : b));

    setState(() {
      _labelResult = _labels.length > predictedIndex ? _labels[predictedIndex] : "Inconnu";
    });

    _getWikiDescription();
  }

// Récupérer une description depuis Wikipédia
  Future<void> _getWikiDescription() async {
    final url = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$_labelResult');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String description = data['extract'] ?? 'Pas de description disponible.';
      setState(() {
        _description = description;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Learn')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Choisissez ou capturez une image"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isModelLoaded ? () => _pickImage(ImageSource.gallery) : null,
              child: const Text("Importer une image"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isModelLoaded ? () => _pickImage(ImageSource.camera) : null,
              child: const Text("Prendre une photo"),
            ),
            if (_isLoading) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            if (!_isLoading && _imageFile.path.isNotEmpty) ResultWidget(label: _labelResult, description: _description,imageFile: _imageFile),
          ],
        ),
      ),
    );
  }
}
