import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ResultWidget extends StatelessWidget {
  final String label;
  final String description;
  final File imageFile;

  const ResultWidget({
    super.key,
    required this.label,
    required this.description,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.file(imageFile, height: 200),
        // Ou utilise une image réelle si tu en as
        const SizedBox(height: 20),
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          description,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _launchGoogleSearch(label),
          child: const Text("Rechercher sur Google"),
        ),
      ],
    );
  }

  Future<void> _launchGoogleSearch(String query) async {
    final url = 'https://www.google.com/search?q=$query';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Impossible d\'ouvrir Google.';
    }
  }
}
