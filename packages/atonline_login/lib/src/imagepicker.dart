import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Callback function for when an image is selected
typedef ImagePickerSaver = void Function(File? image);

/// Interface for image picking functionality
abstract class ImagePickerService {
  /// Takes a photo using the camera
  Future<XFile?> takePhoto();

  /// Selects an image from the gallery
  Future<XFile?> pickImageFromGallery();
}

/// Default implementation of ImagePickerService using image_picker package
class DefaultImagePickerService implements ImagePickerService {
  final ImagePicker _picker;

  DefaultImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  @override
  Future<XFile?> takePhoto() {
    return _picker.pickImage(source: ImageSource.camera);
  }

  @override
  Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(source: ImageSource.gallery);
  }
}

/// A widget that allows selecting an image from camera or gallery
class ImagePickerWidget extends StatefulWidget {
  /// Callback when an image is selected or changed
  final ImagePickerSaver? onChange;

  /// URL to display as the default image
  final String? defaultImageUrl;

  /// Service for picking images, allows for dependency injection and testing
  final ImagePickerService? imagePickerService;

  const ImagePickerWidget({
    Key? key,
    this.onChange,
    this.defaultImageUrl,
    this.imagePickerService,
  }) : super(key: key);

  @override
  ImagePickerWidgetState createState() => ImagePickerWidgetState();
}

class ImagePickerWidgetState extends State<ImagePickerWidget> {
  File? _image;
  late final ImagePickerService _pickerService;

  @override
  void initState() {
    super.initState();
    _pickerService = widget.imagePickerService ?? DefaultImagePickerService();
  }

  /// Takes a photo using the camera
  Future<void> getImage() async {
    final image = await _pickerService.takePhoto();
    _processSelectedImage(image);
  }

  /// Picks an image from the gallery
  Future<void> pickImage() async {
    final image = await _pickerService.pickImageFromGallery();
    _processSelectedImage(image);
  }

  /// Processes the selected image and updates state
  void _processSelectedImage(XFile? image) {
    if (image == null) return;

    setState(() {
      _image = File(image.path);
      if (widget.onChange != null) widget.onChange!(_image);
    });
  }

  /// Builds the image display widget
  Widget _imageWidget() {
    late final ImageProvider img;

    if (_image != null) {
      img = FileImage(_image!);
    } else if (widget.defaultImageUrl != null) {
      img = NetworkImage(widget.defaultImageUrl!);
    } else {
      // Use a placeholder color instead of an asset that might not exist in tests
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height / 3,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueGrey,
            border: Border.all(color: Colors.white, width: 2),
            image: DecorationImage(
              fit: BoxFit.cover,
              alignment: FractionalOffset.center,
              image: img,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: <Widget>[
        _imageWidget(),
        Opacity(
          opacity: 0.5,
          child: Container(
            width: 150,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.all(Radius.circular(30.0)),
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              GestureDetector(
                onTap: getImage,
                child: const Icon(Icons.photo_camera, color: Colors.white),
              ),
              const SizedBox(width: 50),
              GestureDetector(
                onTap: pickImage,
                child: const Icon(Icons.camera_roll, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
