import 'dart:convert';
import 'dart:io';

import 'package:atonline_api/atonline_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hexcolor.dart';
import 'imagepicker.dart';
import 'login_service.dart';

/// Widget that displays a login page for AtOnline API
class AtOnlineLoginPageBody extends StatefulWidget {
  /// Callback URL scheme for OAuth2 authentication
  final String? callbackUrlScheme;

  /// AtOnline API instance
  final AtOnline api;

  /// Action to perform (login, register, etc.)
  final String action;

  /// Callback when login is complete
  final Function()? onComplete;

  /// Login service for API interactions
  final LoginService? loginService;

  const AtOnlineLoginPageBody(
    this.api, {
    Key? key,
    this.callbackUrlScheme,
    this.onComplete,
    this.action = "login",
    this.loginService,
  }) : super(key: key);

  @override
  AtOnlineLoginPageBodyState createState() => AtOnlineLoginPageBodyState();
}

class AtOnlineLoginPageBodyState extends State<AtOnlineLoginPageBody> {
  dynamic info;
  bool busy = true;
  bool canReset = false;
  String session = "";
  Map<String, TextEditingController> fields = {};
  Map<String, File> _files = {};
  Map<String, dynamic> _fileFields = {};

  // Services
  late final LoginService _loginService;

  // Constants
  static const oauth2PerLine = 6;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _loginService = widget.loginService ?? DefaultLoginService(widget.api);

    // Start the login flow
    _submitData();
  }

  /// Shows an error message to the user
  void _showError({String? msg}) {
    final message = msg ?? "An error happened, please retry.";
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    setState(() {
      busy = false;
    });
  }

  /// Handles OAuth2 login flow
  Future<void> _doOauth2Login(String url) async {
    if (widget.callbackUrlScheme == null) {
      _showError(msg: "OAuth2 login is not configured properly.");
      return;
    }

    if (kDebugMode) {
      print('Opening OAuth2 URL');
    }

    try {
      // Launch the URL directly instead of using WebAuthService
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showError(msg: "Could not launch the authentication URL.");
        return;
      }

      // This approach requires the app to handle the callback URL
      // through app links / universal links / deep links
      // Since we can't handle the callback here, we'll just continue with empty session

      // In v2 flow, the callback to the app would include a session
      // This is a placeholder - in a real implementation, you would extract
      // the session from the callback URL
      // For now, we reset the session to empty to start a new flow
      setState(() {
        session = "";
      });
      _submitData(override: {});
    } catch (e) {
      _showError(msg: "Operation has been cancelled: $e");
      return;
    }
  }

  /// Submits login data to the API
  void _submitData({Map<String, String>? override}) async {
    setState(() {
      busy = true;
    });

    // Set canReset if we have a session
    if (session.isNotEmpty) {
      canReset = true;
    }

    Map<String, String> formData = {};

    // If override is not null, use it instead of reading fields
    if (override != null) {
      formData = override;

      if (kDebugMode) {
        // Prepare actual request that will be sent
        final Map<String, dynamic> requestParams = {};

        // Initial vs subsequent requests have different parameters
        if (session.isEmpty) {
          requestParams['action'] = widget.action;
          requestParams['v2'] = true;
          requestParams['client_id'] = widget.api.appId;
          print('🔄 Initial request with override data');
        } else {
          requestParams['session'] = session;
          requestParams['image_variation'] = User.imageVariation;
          print(
              '🔄 Continued request with override data and session: $session');
        }

        // Add all form data to the request
        formData.forEach((key, value) {
          requestParams[key] = value;
        });

        // Log the actual request parameters with all data in dev mode
        print('Request parameters: ${jsonEncode(requestParams)}');
      }
    } else if (fields.isNotEmpty) {
      // Gather all the required fields from the form
      fields.forEach((field, controller) {
        formData[field] = controller.text;
      });

      if (kDebugMode) {
        // Prepare actual request that will be sent
        final Map<String, dynamic> requestParams = {};

        // Initial vs subsequent requests have different parameters
        if (session.isEmpty) {
          requestParams['action'] = widget.action;
          requestParams['v2'] = true;
          requestParams['client_id'] = widget.api.appId;
          print('🔄 Initial request with form data');
        } else {
          requestParams['session'] = session;
          requestParams['image_variation'] = User.imageVariation;
          print('🔄 Continued request with form data and session: $session');
        }

        // Add all form data to the request
        formData.forEach((key, value) {
          requestParams[key] = value;
        });

        // Log the actual request parameters with all data in dev mode
        print('Request parameters: ${jsonEncode(requestParams)}');
      }
    }

    try {
      final res = await _loginService.submitLoginData(
        action: widget.action,
        session: session,
        formData: formData,
      );

      if (kDebugMode) {
        print('📥 Login response status - Type: ${res.runtimeType}');

        // Log the actual response data without masking in dev mode
        try {
          if (res is Map) {
            // Log all data including tokens
            print('Response data: ${jsonEncode(res)}');
          } else if (res is List) {
            // Log the complete list with tokens
            print('Response data (list): ${jsonEncode(res)}');
          } else {
            print(
                'Response data type not directly serializable: ${res.runtimeType}');
          }
        } catch (e) {
          print('Failed to serialize response: $e');
        }
      }

      bool isComplete = false;
      String? url;

      // Handle different response formats
      if (res is Map<String, dynamic>) {
        isComplete = res["complete"] == true;
        url = res["url"];

        if (kDebugMode) {
          print('  Map format - Complete: $isComplete');
          print('  Has URL: ${url != null}');
          print('  Has session: ${res["session"] != null}');
        }
      } else if (res is List && res.length >= 1) {
        isComplete = res[0] == true;

        // For tuple format (true, token, [...])
        if (res.length >= 2 && res[1] is String && !res[1].startsWith("http")) {
          // This is likely a completion token
        } else if (res.length >= 2 &&
            res[1] is String &&
            res[1].startsWith("http")) {
          // This is likely a redirect URL
          url = res[1];
        }

        if (kDebugMode) {
          print('  List format - Complete: $isComplete');
          print('  Has URL: ${url != null}');
        }
      }

      if (isComplete) {
        // Flow is complete, handle success
        if (kDebugMode) {
          print('✅ Login flow complete, handling success');
        }
        await _handleLoginSuccess(res);
      } else if (url != null) {
        // Special case for OAuth2 - redirect to external URL
        if (kDebugMode) {
          print('🔀 Redirecting to OAuth2 URL: $url');
        }
        _doOauth2Login(url);
        return;
      } else {
        // Continue the flow with the next step
        if (kDebugMode) {
          print('➡️ Continuing login flow with next step');
        }
        _updateLoginForm(res);
      }
    } on AtOnlinePlatformException catch (e) {
      if (kDebugMode) {
        print("❌ Platform error: ${e.data}");
      }
      _showError(msg: "API Error: ${e.data['error'] ?? 'Unknown error'}");
    } catch (e) {
      if (kDebugMode) {
        print("❌ Login error: $e");
      }
      _showError();
    }
  }

  /// Handles successful login response
  Future<void> _handleLoginSuccess(dynamic response) async {
    try {
      if (kDebugMode) {
        print('Handling login success with response:');
        print(response);
        print('Response type: ${response.runtimeType}');
      }

      Map<String, dynamic>?
          token; // Must be a Map containing access_token, refresh_token, etc.
      String? redirectUrl;

      // Handle different response formats
      dynamic tokenObj;

      if (response is Map<String, dynamic>) {
        // Standard map format
        tokenObj = response["Token"] ?? response["token"];
        redirectUrl = response["Redirect"] ?? response["redirect"];

        // Token must be a Map
        if (tokenObj is Map<String, dynamic>) {
          if (kDebugMode) {
            print('Token is a Map object');
          }

          // Cast to proper Map<String, dynamic> type
          token = Map<String, dynamic>.from(tokenObj);
        } else {
          if (kDebugMode && tokenObj != null) {
            print('Unexpected token format: ${tokenObj.runtimeType}');
            print('Expected a Map<String, dynamic>');
          }
          token = null;
        }
      } else if (response is List && response.length >= 2) {
        // Tuple format (true, token, [...])
        if (response[0] == true) {
          if (response[1] is Map<String, dynamic>) {
            // Handle tuple with token object
            token = Map<String, dynamic>.from(response[1]);
          } else {
            if (kDebugMode) {
              print(
                  'Tuple format response[1] is not a Map: ${response[1]?.runtimeType}');
            }
          }
        }
      }

      if (kDebugMode) {
        print('Extracted token: ${token != null ? 'Found' : 'Not found'}');
        print('Extracted redirect: $redirectUrl');
      }

      if (token == null) {
        if (kDebugMode) {
          print("No token in response");
        }
        _showError(msg: "Login failed: No authentication token received");
        return;
      }

      if (kDebugMode) {
        print('Using token object (treated as opaque)');
      }

      final isLoggedIn = await _loginService.completeLogin(token);

      if (isLoggedIn) {
        // Upload any files if needed
        if (_files.isNotEmpty) {
          await _loginService.uploadFiles(_files, _fileFields);
        }

        // Handle redirect if provided in the response
        if (redirectUrl != null) {
          // Handle internal or external redirects
          if (redirectUrl.startsWith("http://") ||
              redirectUrl.startsWith("https://")) {
            launchUrl(Uri.parse(redirectUrl));
          } else {
            // For internal app routes
            if (kDebugMode) {
              print("Internal redirect requested to: $redirectUrl");
            }
            // Navigation would depend on the app's routing system
          }
        }
      }

      // Complete login flow
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacementNamed("/home");
      }
    } catch (e) {
      print("Login completion error: $e");
      _showError();
    }
  }

  /// Updates the login form with new data
  void _updateLoginForm(dynamic res) {
    if (kDebugMode) {
      print('Updating login form with data type: ${res.runtimeType}');
    }

    // Convert response to Map if it's a list or tuple format
    Map<String, dynamic> responseMap = {};

    if (res is List) {
      if (kDebugMode) {
        print('Converting list response to map');
      }

      // In tuple format like (false, null, [...fields])
      if (res.length >= 3 && res[2] is List) {
        // Handle the tuple format - array of buttons is in the third position
        List<dynamic> fields = res[2];

        if (kDebugMode) {
          print('Found ${fields.length} buttons/fields in tuple format');
        }

        // Convert fields to ensure the right structure for OAuth2 buttons
        for (var i = 0; i < fields.length; i++) {
          if (fields[i] is Map &&
              fields[i]["button"] != null &&
              fields[i]["type"] == null) {
            fields[i]["type"] = "oauth2";
          }
        }

        responseMap = {
          "complete": res[0],
          "message": "Please select your login method",
          "fields": fields,
        };
      }
    } else if (res is Map<String, dynamic>) {
      responseMap = res;
    } else {
      if (kDebugMode) {
        print('❌ Unexpected response format: ${res.runtimeType}');
      }
      _showError(msg: "Unexpected response format from server");
      return;
    }

    setState(() {
      info = responseMap;

      // Get session from response
      if (responseMap["session"] != null) {
        session = responseMap["session"];
      }

      // Reset field controllers
      fields = {};

      // Create controllers for required fields
      if (responseMap["req"] != null && responseMap["req"] is List) {
        for (var field in responseMap["req"]) {
          fields[field] = TextEditingController();
        }
      }

      // v2 format might include initial values for fields
      if (responseMap["fields"] != null && responseMap["fields"] is List) {
        for (var field in responseMap["fields"]) {
          final name = field["name"];
          final defaultVal = field["default"];

          // If field is required but not yet added
          if (name != null && fields[name] == null) {
            // Add it with default value if available
            fields[name] = TextEditingController(
              text: defaultVal != null ? defaultVal.toString() : "",
            );
          } else if (name != null && defaultVal != null) {
            // Or update existing with default value
            fields[name]?.text = defaultVal.toString();
          }
        }
      }

      busy = false;
    });
  }

  /// Creates an OAuth2 button widget
  Widget _makeOAuth2Button(dynamic info) {
    // Format in v2: type: "oauth2", id: "provider_id", info: {}, button: {...}
    Widget child;
    Color backgroundColor = Theme.of(context).primaryColor;
    Color? textColor;

    if (info["button"] != null) {
      // Extract button styling from v2 format
      dynamic buttonInfo = info["button"];
      String? text = buttonInfo["text"];
      String? logo = buttonInfo["logo"];
      String? icon = buttonInfo["icon"];

      // Logo is used in some formats, icon in others
      String? imageSource = logo ?? icon;

      if (imageSource != null) {
        // Handle SVG icon
        if (imageSource.startsWith("data:")) {
          try {
            // Parse data URI
            final data = UriData.parse(imageSource);
            final svgData = data.contentAsString();

            // For SVG specifically
            if (imageSource.contains("svg")) {
              child = LayoutBuilder(
                builder: (context, constraint) => SvgPicture.string(
                  svgData,
                  height: constraint.biggest.height * 0.6,
                ),
              );
            } else {
              // Default to text if SVG parsing fails
              child = Text(info["id"] ?? "Login", textAlign: TextAlign.center);
            }
          } catch (e) {
            // Fallback to text
            child = Text(info["id"] ?? "Login", textAlign: TextAlign.center);
          }
        } else {
          // Network image
          try {
            child = LayoutBuilder(
              builder: (context, constraint) => SvgPicture.network(
                imageSource,
                height: constraint.biggest.height * 0.6,
              ),
            );
          } catch (e) {
            // Fallback to text
            child = Text(info["id"] ?? "Login", textAlign: TextAlign.center);
          }
        }
      } else if (text != null) {
        // Use text if no icon
        textColor = buttonInfo["textColor"] != null
            ? HexColor.fromHex(buttonInfo["textColor"])
            : Colors.white;
        child = Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor),
        );
      } else {
        // Fallback to provider name
        child = Text(info["id"] ?? "Login", textAlign: TextAlign.center);
      }

      // Apply colors if provided
      String? color = buttonInfo["color"] ?? buttonInfo["background-color"];
      if (color != null) {
        backgroundColor = HexColor.fromHex(color);
      }
    } else {
      // Fallback for when button styling is not provided
      child = Text(info["id"] ?? "Login", textAlign: TextAlign.center);
    }

    return GestureDetector(
      onTap: () => _doOAuth2Login(info),
      child: Container(
        margin: const EdgeInsets.all(5),
        alignment: Alignment.center,
        child: child,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(3.0, 3.0),
              blurRadius: 5.0,
            ),
          ],
        ),
      ),
    );
  }

  /// Handles OAuth2 login button tap
  void _doOAuth2Login(dynamic info) async {
    if (widget.callbackUrlScheme == null) {
      _showError(msg: "OAuth2 login is not configured properly.");
      return;
    }

    // In v2 flow, this triggers the OAuth2 flow by sending the provider id and session
    // For the redirect_uri, use the callback scheme provided by the app
    final redirectUri = "${widget.callbackUrlScheme}://";

    if (kDebugMode) {
      print('OAuth2 login with provider ${info["id"]}');
      print('Using redirect URI: $redirectUri');
    }

    _submitData(override: {
      "oauth2": info["id"],
      "redirect_uri": redirectUri,
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Container();

    if (info != null) {
      if (kDebugMode) {
        print('Building login UI with ${info["fields"]?.length ?? 0} fields');
      }

      final widgets = <Widget>[];

      // Add message - provide a default if missing
      final message = info["message"] ?? "Please select your login method";
      widgets
          .add(Text(message.toString(), style: const TextStyle(fontSize: 16)));

      // Add user info if available
      if (info["user"] != null) {
        _buildUserInfoSection(widgets, info);
      } else if (info["email"] != null) {
        widgets.add(const SizedBox(height: 15));
        widgets.add(Text(
          info["email"],
          style: const TextStyle(fontSize: 24),
        ));
      }

      // Add form fields
      if (info["fields"] != null) {
        _buildFormFields(widgets, info["fields"]);
      }

      // Add action buttons
      widgets.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          canReset
              ? TextButton(
                  onPressed: () {
                    setState(() {
                      fields = {};
                      info = null;
                      session = "";
                      canReset = false;
                    });
                    _submitData();
                  },
                  child:
                      const Text("Reset", style: TextStyle(color: Colors.red)),
                )
              : Container(),
          ElevatedButton(
            onPressed: _submitData,
            child: const Text("Submit"),
          ),
        ],
      ));

      // Build the final card
      body = SingleChildScrollView(
        child: Center(
          child: Card(
            child: Container(
              margin: const EdgeInsets.all(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widgets,
              ),
            ),
          ),
        ),
      );
    } else {
      body = const SingleChildScrollView(child: SizedBox());
    }

    // Create the final stack with loading indicator
    final stack = <Widget>[Center(child: body)];

    if (busy) {
      // If busy, stack a modal barrier and a progress indicator on top
      stack.add(const Opacity(
        opacity: 0.2,
        child: ModalBarrier(color: Colors.black),
      ));
      stack.add(const Center(child: CircularProgressIndicator()));
    }

    return Stack(children: stack);
  }

  /// Builds the user info section
  void _buildUserInfoSection(List<Widget> widgets, dynamic info) {
    widgets.add(const SizedBox(height: 15));
    widgets.add(Row(children: <Widget>[
      info["user"]["Profile"]["Media_Image"] != null
          ? Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white),
                image: DecorationImage(
                    image: NetworkImage(info["user"]["Profile"]["Media_Image"]
                        ["Variation"][User.imageVariation]),
                    fit: BoxFit.cover),
              ),
            )
          : Container(),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            info["user"]["Profile"]["Display_Name"],
            style: const TextStyle(fontSize: 24),
          ),
          Text(info["user"]["Email"]),
        ],
      )
    ]));
  }

  /// Builds form fields from the fields data
  void _buildFormFields(List<Widget> widgets, List<dynamic> fieldsData) {
    var firstField = true;
    List<Widget> oauth2Buttons = [];

    if (kDebugMode) {
      print('Building ${fieldsData.length} form fields');
    }

    for (var field in fieldsData) {
      // v2 flow categorizes fields with "cat" field
      final String fieldType = field["type"] ?? "";
      final String fieldCategory = field["cat"] ?? "";

      // Special case for OAuth2 buttons which might not have type set
      if (field["button"] != null &&
          (fieldType.isEmpty || fieldType == "oauth2")) {
        if (kDebugMode) {
          print('Found OAuth2 button');
        }

        oauth2Buttons.add(GridTile(
          child: _makeOAuth2Button(field),
        ));
        continue;
      }

      // Handle field based on category and type
      if (fieldCategory == "label" || fieldType == "label") {
        _buildLabelField(widgets, field);
      } else if (fieldCategory == "input") {
        // Handle input fields based on type
        switch (fieldType) {
          case "email":
            _buildTextField(
                widgets, field, firstField, TextInputType.emailAddress);
            firstField = false;
            break;
          case "phone":
            _buildTextField(widgets, field, firstField, TextInputType.phone);
            firstField = false;
            break;
          case "password":
            _buildPasswordField(widgets, field, firstField);
            firstField = false;
            break;
          case "text":
            _buildTextField(widgets, field, firstField, TextInputType.text);
            firstField = false;
            break;
          case "checkbox":
            _buildCheckboxField(widgets, field);
            break;
          case "select":
            _buildSelectField(widgets, field);
            firstField = false;
            break;
          default:
            if (kDebugMode) {
              print("Unhandled input field type: $fieldType");
            }
        }
      } else if (fieldType == "oauth2") {
        oauth2Buttons.add(GridTile(
          child: _makeOAuth2Button(field),
        ));
      } else if (fieldCategory == "special" && fieldType == "image") {
        _buildImageField(widgets, field);
      } else {
        if (kDebugMode) {
          print(
              "Unhandled field type: $fieldType with category: $fieldCategory");
        }
      }
    }

    // Arrange OAuth2 buttons if there are any
    if (oauth2Buttons.isNotEmpty) {
      if (kDebugMode) {
        print('Found ${oauth2Buttons.length} OAuth2 buttons to arrange');
      }

      if (widget.callbackUrlScheme != null) {
        _arrangeOAuth2Buttons(widgets, oauth2Buttons);
      } else if (kDebugMode) {
        print('OAuth2 buttons found but callbackUrlScheme not configured');
      }
    }
  }

  /// Builds a select/dropdown field - new in v2
  void _buildSelectField(List<Widget> widgets, dynamic field) {
    // Check if field name exists
    if (field["name"] == null) {
      print("Select field missing name");
      return;
    }

    // Default value
    String currentValue = "";

    // Initialize the field controller if needed
    if (fields[field["name"]] != null) {
      // If we have an existing value, use that
      currentValue = fields[field["name"]]!.text;
    } else if (field["default"] != null) {
      // Initialize with default if available
      currentValue = field["default"].toString();
      fields[field["name"]] = TextEditingController(text: currentValue);
    } else {
      // Otherwise empty controller
      fields[field["name"]] = TextEditingController();
    }

    // Check if this is a dynamic select
    if (field["source"] != null) {
      _buildDynamicSelectField(widgets, field, currentValue);
      return;
    }

    // Build static dropdown items
    List<DropdownMenuItem<String>> items = [];
    if (field["values"] != null && field["values"] is List) {
      for (var value in field["values"]) {
        if (value["value"] != null && value["display"] != null) {
          items.add(DropdownMenuItem<String>(
            value: value["value"].toString(),
            child: Text(value["display"].toString()),
          ));
        }
      }
    }

    // Create dropdown
    widgets.add(
      DropdownButtonFormField<String>(
        key: Key(field["name"]),
        initialValue: currentValue.isNotEmpty ? currentValue : null,
        decoration: InputDecoration(
          labelText: field["label"] ?? "Select",
        ),
        items: items,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              fields[field["name"]]?.text = value;
            });
          }
        },
      ),
    );
    widgets.add(const SizedBox(height: 15));
  }

  /// Builds a dynamic select field that fetches options from an API
  void _buildDynamicSelectField(
      List<Widget> widgets, dynamic field, String currentValue) {
    final source = field["source"];
    if (source == null || source["api"] == null) {
      print("Dynamic select missing source or api field");
      return;
    }

    final String api = source["api"];
    final String labelField = source["label_field"] ?? "name";
    final String keyField = source["key_field"] ?? "id";

    // Create a loading dropdown initially
    widgets.add(
      FutureBuilder<List<DropdownMenuItem<String>>>(
        future: _fetchDynamicOptions(api, labelField, keyField),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while waiting for API response
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 15),
              ],
            );
          } else if (snapshot.hasError) {
            // Show error message if API call fails
            print("Error loading dynamic select options: ${snapshot.error}");
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Could not load options",
                    style: TextStyle(color: Colors.red)),
                const SizedBox(height: 15),
              ],
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            // Create the dropdown with fetched options
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: Key(field["name"]),
                  initialValue: currentValue.isNotEmpty ? currentValue : null,
                  decoration: InputDecoration(
                    labelText: field["label"] ?? "Select",
                  ),
                  items: snapshot.data,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        fields[field["name"]]?.text = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 15),
              ],
            );
          } else {
            // Show message if no options were returned
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("No options available",
                    style: TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 15),
              ],
            );
          }
        },
      ),
    );
  }

  /// Fetches dynamic select options from the API
  Future<List<DropdownMenuItem<String>>> _fetchDynamicOptions(
      String api, String labelField, String keyField) async {
    try {
      final result = await _loginService.fetchDynamicOptions(api);

      // Process the results into dropdown items
      List<DropdownMenuItem<String>> items = [];

      // If results is a list, process each item
      if (result is List) {
        for (var item in result) {
          if (item[keyField] != null && item[labelField] != null) {
            items.add(DropdownMenuItem<String>(
              value: item[keyField].toString(),
              child: Text(item[labelField].toString()),
            ));
          }
        }
      }
      // If results is a map (e.g. paginated results), look for items array
      else if (result is Map &&
          result["rows"] != null &&
          result["rows"] is List) {
        for (var item in result["rows"]) {
          if (item[keyField] != null && item[labelField] != null) {
            items.add(DropdownMenuItem<String>(
              value: item[keyField].toString(),
              child: Text(item[labelField].toString()),
            ));
          }
        }
      }

      return items;
    } catch (e) {
      print("Error fetching dynamic options: $e");
      throw e;
    }
  }

  /// Builds a label field
  void _buildLabelField(List<Widget> widgets, dynamic field) {
    // Handle style for error messages
    TextStyle style = const TextStyle();
    if (field["style"] == "error") {
      style = const TextStyle(color: Colors.red);
    } else if (field["link"] != null) {
      style = const TextStyle(decoration: TextDecoration.underline);
    }

    if (field["link"] == null) {
      widgets.add(Text(
        field["label"].toString(),
        style: style,
      ));
    } else {
      widgets.add(GestureDetector(
        onTap: () => launchUrl(Uri.parse(field["link"])),
        child: Text(
          field["label"].toString(),
          style: style,
        ),
      ));
    }
    widgets.add(const SizedBox(height: 15));
  }

  /// Builds a text input field
  void _buildTextField(List<Widget> widgets, dynamic field, bool autofocus,
      TextInputType keyboardType) {
    widgets.add(TextFormField(
      key: Key(field["name"]),
      controller: fields[field["name"]],
      keyboardType: keyboardType,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: field["label"].toString(),
      ),
    ));
    widgets.add(const SizedBox(height: 15));
  }

  /// Builds a password field
  void _buildPasswordField(
      List<Widget> widgets, dynamic field, bool autofocus) {
    widgets.add(TextFormField(
      key: Key(field["name"]),
      controller: fields[field["name"]],
      obscureText: true,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: field["label"].toString(),
      ),
    ));
    widgets.add(const SizedBox(height: 15));
  }

  /// Builds a checkbox field
  void _buildCheckboxField(List<Widget> widgets, dynamic field) {
    widgets.add(Row(
      children: <Widget>[
        Checkbox(
          value: (fields[field["name"]]?.text ?? "") == "1",
          onChanged: (value) {
            setState(() {
              fields[field["name"]]?.text = value! ? "1" : "";
            });
          },
        ),
        field["link"] != null
            ? GestureDetector(
                onTap: () => launchUrl(Uri.parse(field["link"])),
                child: Text(
                  field["label"].toString(),
                  style: const TextStyle(decoration: TextDecoration.underline),
                ),
              )
            : Text(field["label"].toString()),
      ],
    ));
    widgets.add(const SizedBox(height: 15));
  }

  /// Builds an image picker field
  void _buildImageField(List<Widget> widgets, dynamic field) {
    if (field["label"] != null) {
      widgets.add(Text(field["label"].toString()));
    }
    widgets.add(ImagePickerWidget(
      onChange: (img) {
        if (img == null) {
          _files.remove(field["name"]);
        } else {
          _files[field["name"]] = img;
        }
        _fileFields[field["name"]] = field;
      },
    ));
  }

  /// Arranges OAuth2 buttons in rows
  void _arrangeOAuth2Buttons(List<Widget> widgets, List<Widget> oauth2Buttons) {
    // Calculate optimal button width based on screen size
    double buttonWidth =
        ((MediaQuery.of(context).size.width - 30) / oauth2PerLine) * 0.95;
    if (buttonWidth > 70) buttonWidth = 70;

    while (oauth2Buttons.isNotEmpty) {
      List<Widget> currentRow;
      if (oauth2Buttons.length > oauth2PerLine) {
        currentRow = oauth2Buttons.sublist(0, oauth2PerLine);
        oauth2Buttons = oauth2Buttons.sublist(oauth2PerLine);
      } else {
        currentRow = oauth2Buttons;
        oauth2Buttons = [];
      }

      final rowChildren = currentRow
          .map((button) => SizedBox(
                width: buttonWidth,
                height: buttonWidth,
                child: button,
              ))
          .toList();

      widgets.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: rowChildren,
      ));
    }

    // Add spacing after the buttons
    widgets.add(const SizedBox(height: 15));
  }
}
