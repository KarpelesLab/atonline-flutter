import 'dart:io';
import 'dart:math';

import 'package:atonline_api/atonline_api.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'imagepicker.dart';

class AtOnlineLoginPageBody extends StatefulWidget {
  final String redirectUri;
  final AtOnline api;

  AtOnlineLoginPageBody(this.api, {this.redirectUri});

  @override
  _AtOnlineLoginPageBodyState createState() => _AtOnlineLoginPageBodyState();
}

class _AtOnlineLoginPageBodyState extends State<AtOnlineLoginPageBody> {
  dynamic info;
  bool busy = true;
  bool canReset = false;
  String session = "";
  String _clientSessionId; // random string used to identify progress in session
  Map<String, TextEditingController> fields;
  Map<String, File> _files = {};
  Map<String, dynamic> _fileFields = {}; // fields about files (which are set)
  static const oauth2PerLine = 6;

  /// Generates a random integer where [from] <= [to].
  int _randomBetween(int from, int to) {
    if (from > to) throw new Exception('$from cannot be > $to');
    var rand = new Random.secure();
    return ((to - from) * rand.nextDouble()).truncate() + from;
  }

  @override
  void initState() {
    _submitData();
    _clientSessionId = String.fromCharCodes(
        List.generate(64, (index) => _randomBetween(33, 126)));
    Links().addListener(widget.redirectUri, _loginListener);
    super.initState();
  }

  @override
  void dispose() {
    Links().removeListener(widget.redirectUri, _loginListener);
    super.dispose();
  }

  void _loginListener(Uri l) async {
    await closeWebView();

    var qp = l.queryParameters;
    if (qp["session"] == null) {
      // cancel
      // TODO handle errors?
      Navigator.of(context).pop();
      return;
    }

    // refresh this new session
    session = qp["session"];
    _submitData(override: {}); // send empty form
  }

  void _submitData({Map<String, String> override}) async {
    var body = <String, String>{
      "client_id": widget.api.appId,
      "image_variation": User.imageVariation,
      "session": session,
      "client_sid": _clientSessionId,
    };
    if (session != "") {
      canReset = true;
    }

    if (override != null) {
      override.forEach((k, v) {
        body[k] = v;
      });
    } else if (fields != null) {
      fields.forEach((field, c) {
        body[field] = c.text;
      });
    }

    print("body = $body");

    setState(() {
      busy = true;
    });
    var res;
    try {
      res = await widget.api.req("User:flow", method: "POST", body: body);
    } on AtOnlinePlatformException {
      Scaffold.of(context)
          .showSnackBar(SnackBar(content: Text("ERROR (todo)")));
      setState(() {
        busy = false;
      });
      return;
    }

    if (res["complete"]) {
      // we got a login!
      try {
        await widget.api.storeToken(res["Token"]);
        await widget.api.user.fetchLogin();

        if (widget.api.user.isLoggedIn()) {
          // perform files
          if (_files.length > 0) {
            var futures = <Future>[];
            _files.forEach((k, f) {
              var fi = _fileFields[k];
              futures.add(
                  widget.api.authReqUpload(fi["target"], f, body: fi["param"]));
            });
            await Future.wait(futures);

            await widget.api.user.fetchLogin(); // once again with love
          }
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacementNamed("/home");
          return;
        } else {
          // show error?
        }
      } catch (e) {
        // show error?
      }
    }

    if (res["url"] != null) {
      // special case → open given url, do nothing else
      launch(res["url"]);
      setState(() {
        busy = false;
      });
      return;
    }

    setState(() {
      info = res;
      session = res["session"];
      fields = {};
      info["req"].forEach((v) {
        fields[v] = TextEditingController();
      });
      busy = false;
    });
  }

  Widget _makeOAuth2Button(dynamic info) {
    // info[info] contains: Token_Name, Name, Client_Id, Scope[]
    Widget chld = Text(info["info"]["Name"], textAlign: TextAlign.center);
    Color col = Theme.of(context).primaryColor;

    switch (info["info"]["Token_Name"]) {
      case "google":
        chld = LayoutBuilder(
            builder: (context, constraint) => Icon(MdiIcons.google,
                size: constraint.biggest.height * 0.6, color: Colors.white));

        col = Color(0xffDB4437);

        break;
      case "facebook":
        chld = LayoutBuilder(
            builder: (context, constraint) => Icon(MdiIcons.facebook,
                size: constraint.biggest.height * 0.6, color: Colors.white));
        col = Color(0xff3C5A99);
        break;
      case "twitter":
        chld = LayoutBuilder(
            builder: (context, constraint) => Icon(MdiIcons.twitter,
                size: constraint.biggest.height * 0.6, color: Colors.white));
        col = Color(0xff1da1f2);
        break;
      case "yahoo_japan":
        chld = Container(
            margin: EdgeInsets.all(5),
            child: Image.asset(
              "assets/Yahoo_Favicon_1997.png",
            ));
        col = Colors.white;
        break;
      case "amazon":
        chld = LayoutBuilder(
            builder: (context, constraint) => Icon(MdiIcons.amazon,
                size: constraint.biggest.height * 0.6, color: Colors.white));
        col = Color(0xffFF9900);
        break;
      case "reddit":
        chld = LayoutBuilder(
            builder: (context, constraint) => Icon(MdiIcons.reddit,
                size: constraint.biggest.height * 0.6, color: Colors.white));
        col = Color(0xffFF4500);
        break;
    }

    Widget btn = Container(
      margin: EdgeInsets.all(5),
      alignment: Alignment.center,
      child: chld,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: col,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black26,
            offset: new Offset(3.0, 3.0),
            blurRadius: 5.0,
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => _doOAuth2Login(info),
      child: btn,
    );
  }

  void _doOAuth2Login(dynamic info) async {
    _submitData(
        override: {"oauth2": info["id"], "redirect_uri": widget.redirectUri});
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Container();

    if (info != null) {
      var l = <Widget>[];

      l.add(Text(info["message"].toString(), style: TextStyle(fontSize: 16)));

      if (info["user"] != null) {
        // show user info
        l.add(Container(height: 15));
        l.add(Row(children: <Widget>[
          info["user"]["Profile"]["Media_Image"] != null
              ? Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white),
                    image: DecorationImage(
                        image: NetworkImage(info["user"]["Profile"]
                            ["Media_Image"]["Variation"][User.imageVariation]),
                        fit: BoxFit.cover),
                  ),
                )
              : Container(),
          Container(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                info["user"]["Profile"]["Display_Name"],
                style: TextStyle(
                  fontSize: 24,
                ),
              ),
              Text(
                info["user"]["Email"],
              ),
            ],
          )
        ]));
      } else if (info["email"] != null) {
        l.add(Container(height: 15));
        l.add(Text(
          info["email"],
          style: TextStyle(
            fontSize: 24,
          ),
        ));
      }

      if (info["fields"] != null) {
        var firstField = true;
        List<Widget> oauth2 = [];

        info["fields"].forEach((info) {
          switch (info["type"]) {
            case "label":
              // need to show a label
              if (info["link"] == null) {
                l.add(Text(info["label"].toString()));
              } else {
                l.add(GestureDetector(
                  onTap: () => launch(info["link"]),
                  child: Text(
                    info["label"].toString(),
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ));
              }
              l.add(Container(height: 15));
              break;
            case "email":
              l.add(TextFormField(
                key: Key(info["name"]),
                controller: fields[info["name"]],
                keyboardType: TextInputType.emailAddress,
                autofocus: firstField,
                decoration: InputDecoration(
                  labelText: info["label"].toString(),
                ),
              ));
              firstField = false;
              l.add(Container(height: 15));
              break;
            case "password":
              l.add(TextFormField(
                key: Key(info["name"]),
                controller: fields[info["name"]],
                obscureText: true,
                autofocus: firstField,
                decoration: InputDecoration(
                  labelText: info["label"].toString(),
                ),
              ));
              firstField = false;
              l.add(Container(height: 15));
              break;
            case "text":
              l.add(TextFormField(
                key: Key(info["name"]),
                controller: fields[info["name"]],
                autofocus: firstField,
                decoration: InputDecoration(
                  labelText: info["label"].toString(),
                ),
              ));
              firstField = false;
              l.add(Container(height: 15));
              break;
            case "checkbox":
              l.add(Row(
                children: <Widget>[
                  Checkbox(
                    value: fields[info["name"]].text == "1",
                    onChanged: (v) {
                      setState(() {
                        fields[info["name"]].text = v ? "1" : "";
                      });
                    },
                  ),
                  info["link"] != null
                      ? GestureDetector(
                          onTap: () => launch(info["link"]),
                          child: Text(
                            info["label"].toString(),
                            style:
                                TextStyle(decoration: TextDecoration.underline),
                          ),
                        )
                      : Text(info["label"].toString()),
                ],
              ));
              l.add(Container(height: 15));
              break;
            case "oauth2":
              oauth2.add(GridTile(
                child: _makeOAuth2Button(info),
              ));
              break;
            case "image":
              if (info["label"] != null) l.add(Text(info["label"].toString()));
              l.add(ImagePickerWidget(
                onChange: (img) {
                  _files[info["name"]] = img;
                  _fileFields[info["name"]] = info;
                },
              ));
              break;
            default:
              print("unhandled field: $info");
          }
        });

        if ((oauth2.length > 0) && (widget.redirectUri != null)) {
          // can't quite use gridview inside of a SingleChildScrollView it seems
          double width =
              ((MediaQuery.of(context).size.width - 30) / oauth2PerLine) * 0.95;
          while (oauth2.length > 0) {
            List<Widget> t;
            if (oauth2.length > oauth2PerLine) {
              t = oauth2.sublist(0, oauth2PerLine);
              oauth2 = oauth2.sublist(oauth2PerLine);
            } else {
              t = oauth2;
              oauth2 = [];
            }
            List<Widget> t2 = [];
            t.forEach((v) {
              t2.add(Container(
                width: width,
                height: width,
                child: v,
              ));
            });
            l.add(Row(children: t2));
          }
          l.add(Container(height: 15));
        }
      }

      l.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          canReset
              ? FlatButton(
                  onPressed: () {
                    fields = null;
                    info = null;
                    session = "";
                    canReset = false;
                    _submitData();
                  },
                  child: Text("Reset", style: TextStyle(color: Colors.red)),
                )
              : Container(),
          RaisedButton(
            onPressed: _submitData,
            child: Text("Submit"),
          ),
        ],
      ));

      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: l,
      );
      body = Center(
          child: Card(
        child: Container(
          margin: EdgeInsets.all(15),
          child: body,
        ),
      ));
    }

    body = SingleChildScrollView(
      child: body,
    );

    var l = <Widget>[Center(child: body)];

    if (busy) {
      l.add(Opacity(
        opacity: 0.2,
        child: ModalBarrier(
          color: Colors.black,
        ),
      ));
      l.add(Center(
        child: CircularProgressIndicator(),
      ));
    }

    return Stack(children: l);
  }
}
