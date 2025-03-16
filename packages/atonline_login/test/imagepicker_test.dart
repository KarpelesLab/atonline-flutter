import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atonline_login/src/imagepicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

// Mock implementation of ImagePickerService for testing
class MockImagePickerService implements ImagePickerService {
  bool cameraCalled = false;
  bool galleryCalled = false;
  XFile? returnValue;
  
  MockImagePickerService({this.returnValue});
  
  @override
  Future<XFile?> takePhoto() async {
    cameraCalled = true;
    return returnValue;
  }
  
  @override
  Future<XFile?> pickImageFromGallery() async {
    galleryCalled = true;
    return returnValue;
  }
  
  void reset() {
    cameraCalled = false;
    galleryCalled = false;
  }
}

void main() {
  group('ImagePickerWidget', () {
    testWidgets('renders correctly with default parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImagePickerWidget(),
          ),
        ),
      );

      // Verify the widget renders
      expect(find.byType(ImagePickerWidget), findsOneWidget);
      
      // Check for camera and gallery icons
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
      expect(find.byIcon(Icons.camera_roll), findsOneWidget);
    });

    // Skip this test since we can't load network images in tests
    // testWidgets('displays network image when defaultImageUrl is provided', 
    //     (WidgetTester tester) async {
    //   await tester.pumpWidget(
    //     const MaterialApp(
    //       home: Scaffold(
    //         body: ImagePickerWidget(
    //           defaultImageUrl: 'https://example.com/image.jpg',
    //         ),
    //       ),
    //     ),
    //   );

    //   // Verify the widget renders
    //   expect(find.byType(ImagePickerWidget), findsOneWidget);
      
    //   // Check for DecorationImage - we can't check the actual network image,
    //   // but we can verify the container with decoration exists
    //   expect(find.byType(Container), findsWidgets);
    // });
    
    testWidgets('calls takePhoto when camera icon is tapped', 
        (WidgetTester tester) async {
      final mockService = MockImagePickerService();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePickerWidget(
              imagePickerService: mockService,
            ),
          ),
        ),
      );
      
      // Tap the camera icon
      await tester.tap(find.byIcon(Icons.photo_camera));
      await tester.pump();
      
      // Verify takePhoto was called
      expect(mockService.cameraCalled, isTrue);
      expect(mockService.galleryCalled, isFalse);
    });
    
    testWidgets('calls pickImageFromGallery when gallery icon is tapped', 
        (WidgetTester tester) async {
      final mockService = MockImagePickerService();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePickerWidget(
              imagePickerService: mockService,
            ),
          ),
        ),
      );
      
      // Tap the gallery icon
      await tester.tap(find.byIcon(Icons.camera_roll));
      await tester.pump();
      
      // Verify pickImageFromGallery was called
      expect(mockService.galleryCalled, isTrue);
      expect(mockService.cameraCalled, isFalse);
    });
    
    testWidgets('calls onChange callback when image is selected', 
        (WidgetTester tester) async {
      // Create a temporary file path (won't be used in actual test)
      final tempFilePath = path.join('test', 'test_image.jpg');
      File? capturedFile;
      
      final mockService = MockImagePickerService(
        returnValue: XFile(tempFilePath),
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePickerWidget(
              imagePickerService: mockService,
              onChange: (file) {
                capturedFile = file;
              },
            ),
          ),
        ),
      );
      
      // Tap the camera icon
      await tester.tap(find.byIcon(Icons.photo_camera));
      await tester.pump();
      
      // Verify onChange callback was called with the correct file
      expect(capturedFile, isNotNull);
      expect(capturedFile!.path, equals(tempFilePath));
    });
  });
}