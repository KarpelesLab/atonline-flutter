import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef void ImagePickerSaver(File image);

class ImagePickerWidget extends StatefulWidget {
  final ImagePickerSaver onChange;
  final String defaultImageUrl;

  ImagePickerWidget({this.onChange, this.defaultImageUrl});

  @override
  _ImagePickerWidgetState createState() =>
      _ImagePickerWidgetState(onChange, defaultImageUrl);
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  File _image;
  final ImagePickerSaver onChange;
  final String defaultImageUrl;

  _ImagePickerWidgetState(this.onChange, this.defaultImageUrl);

  Future getImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.camera);

    setState(() {
      _image = image;
      if (onChange != null) onChange(image);
    });
  }

  Future pickImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);

    setState(() {
      _image = image;
      if (onChange != null) onChange(image);
    });
  }

  Widget _imageWidget() {
    ImageProvider img;

    if (_image != null) {
      img = FileImage(_image);
    } else if (defaultImageUrl != null) {
      img = NetworkImage(defaultImageUrl);
    } else {
      img = AssetImage("assets/select_picture.png"); // tbd
    }

    return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height / 3,
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: new Container(
            decoration: new BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey,
                border: Border.all(color: Colors.white, width: 2),
                image: new DecorationImage(
                  fit: BoxFit.cover,
                  alignment: FractionalOffset.center,
                  image: img,
                )),
          ),
        ));
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
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.all(Radius.circular(30.0)),
              ),
            )),
        Container(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  onTap: getImage,
                  child: Icon(Icons.photo_camera, color: Colors.white),
                ),
                Container(width: 50),
                GestureDetector(
                  onTap: pickImage,
                  child: Icon(Icons.camera_roll, color: Colors.white),
                ),
              ],
            )),
      ],
    );
  }
}
