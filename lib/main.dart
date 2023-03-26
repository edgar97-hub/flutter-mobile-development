import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupFlutterNotifications();
  print('Handling a background message ${message.data}');
  showFlutterNotification(message.data);

}
late AndroidNotificationChannel channel;
bool isFlutterLocalNotificationsInitialized = false;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
    'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  isFlutterLocalNotificationsInitialized = true;
}

void showFlutterNotification(dynamic  message) {
  print('title ${message['title']}');
  print('body ${message['body']}');

    flutterLocalNotificationsPlugin.show(
      1,
      message['title'].toString(),
      message['body'].toString(),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          // TODO add a proper drawable resource to android, for now using
          //      one that already exists in example app.
          icon: 'launch_background',
        ),
      ),
    );
}

Future<void> saveToken(String _token) async {
  try {
    await http.get(
      Uri.parse("https://us-central1-daphtech-31758.cloudfunctions.net/saveToken?code=$_token"),
    );
    print('FCM save token for device sent!');
  } catch (e) {
    print(e);
  }
}

Future<String?> getPermisions() async {

  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
// TODO: handle the received notifications
  } else {
    print('User declined or has not accepted permission');
  }
}

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
var _url = "https://daphtech-31758.web.app";
//var _url = "https://daphtech-31758.web.app/pdf-viewer/1675974553765/sales_history";

var fcmToken;

Future<void> main () async => {
  WidgetsFlutterBinding.ensureInitialized(),
  //await FlutterDownloader.initialize(),
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  FirebaseMessaging.onMessage.listen(_firebaseMessagingBackgroundHandler),
  FirebaseMessaging.onMessageOpenedApp.listen(_firebaseMessagingBackgroundHandler),
  //FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  fcmToken = await FirebaseMessaging.instance.getToken(),


// 3. On iOS, this helps to take the user permissions
  await getPermisions(),




  print('token: ${fcmToken}'),
  saveToken(fcmToken),
  await Permission.storage.request(),
  runApp(MyApp()),
};

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      _url += '?skipMediaPermissionPrompt';
    }
    return MaterialApp(
      home: InAppWebViewPage(),
    );
  }
}

class InAppWebViewPage extends StatefulWidget {
  InAppWebViewPage();

  @override
  _InAppWebViewPageState createState() => new _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  //_InAppWebViewPageState();


   late InAppWebViewController webView;
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (webView != null) {
            if (await webView.canGoBack()) {
              // get the webview history
              WebHistory? webHistory = await webView.getCopyBackForwardList();
              webView.goBack();
              return false;
            }
          }
          return true;
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text("Daphtech")
            ),
            body: Container(
                child: Column(children: <Widget>[
                  Expanded(
                    child: Container(
                      child: InAppWebView(
                        initialUrlRequest: URLRequest(url: Uri.parse(_url)),
                        //initialHeaders: {},
                        initialOptions: InAppWebViewGroupOptions(
                            crossPlatform: InAppWebViewOptions(
                              mediaPlaybackRequiresUserGesture: false,
                              javaScriptEnabled:true,
                              useOnDownloadStart: true,
                              useShouldOverrideUrlLoading: true,
                            ),
                            ios: IOSInAppWebViewOptions(
                              allowsInlineMediaPlayback: true,
                              limitsNavigationsToAppBoundDomains: true,
                            )),
                        onLoadStart: (controller, url) {
                          log("onLoadStart $url");
                          print('on  load start');

                        },
                        onLoadStop: (controller, url) {
                          log("onLoadStop $url");
                        },
                        onLoadError: ( controller, url, code, message) {
                          print("onLoadError $message");

                          //TODO: Show error alert message (Error in receive data from server)
                        },
                        onLoadHttpError: (controller, url, statusCode, description) {
                          print("onLoadHttpError $description");

                          //TODO: Show error alert message (Error in receive data from server)
                        },
            onConsoleMessage: (controller, consoleMessage) {
              print("onConsoleMessage $consoleMessage");

              //TODO: Show error alert message (Error in receive data from server)
            },



                        onWebViewCreated: (InAppWebViewController controller) {
                          //print('token: ),
                          print('on webview created');

                          webView = controller;
                          webView.addJavaScriptHandler(
                            handlerName: "getBlobFile",
                            callback: (data) async {
                              if (data.isNotEmpty) {
                                String receivedFileInBase64 = data[0];
                                String receivedMimeType = data[1];
                                String  fileName =  DateTime.now().millisecond.toString().replaceAll(" ", "");

                                var fileType = receivedMimeType.split('/');

                                print("on getBlobFile1 $receivedFileInBase64");
                                print("on 2 $fileType");

                                _createFileFromBase64(
                                    receivedFileInBase64, fileName, fileType[1]);
                              }
                            },
                          );
                        },
                        onDownloadStartRequest: (controller, url) async {
                          final status = await Permission.storage.request();
                          if (status.isGranted) {
                            print("onDownloadStart $url");
                            var BlobUrl = url.url.toString();
                            var fileName = url.suggestedFilename.toString();
                             print("test $BlobUrl");

                            var jsContent = await rootBundle.loadString("assets/js/base64.js");
                            await controller.evaluateJavascript(
                                source: jsContent.replaceAll("blobUrlPlaceholder", BlobUrl as dynamic ));

                            //Directory? tempDir = await getExternalStorageDirectory();
                            //final taskId = await FlutterDownloader.enqueue(
                            //  url: url.toString(),
                            //  savedDir: "/storage/emulated/0/Download",
                              //savedDir: tempDir?.path,
                            //  fileName: DateTime.now().millisecond.toString().replaceAll(" ", ""),
                            //  showNotification: true, // show download progress in status bar (for Android)
                            //  openFileFromNotification: true, // click on notification to open downloaded file (for Android)
                            //);
                          }

                        },
                        androidOnPermissionRequest: (InAppWebViewController controller,
                            String origin, List<String> resources) async {
                          await Permission.camera.request();
                          return PermissionRequestResponse(
                              resources: resources,
                              action: PermissionRequestResponseAction.GRANT);
                        },

                      ),
                    ),
                  ),
                ]))
        )
    );
  }

  Future<void> _createFileFromBase64(String base64content, String fileName, String extension) async {
      var bytes = base64Decode(base64content.replaceAll('\n', ''));
      //final output = await getExternalStorageDirectory();
      //Directory? output = Platform.isAndroid
      //    ? await getExternalStorageDirectory() //FOR ANDROID
      //    : await getApplicationDocumentsDirectory(); //FOR iOS
      Directory? output = await getDownloadPath();
      final file = File("${output?.path}/$fileName.$extension");
      await file.writeAsBytes(bytes.buffer.asUint8List());
      print("on _createFileFromBase64");
      print("${output?.path}/${fileName}.$extension");
      await OpenFile.open("${output?.path}/$fileName.$extension");
      setState(() {});
  }

   Future<Directory?> getDownloadPath() async {
     Directory? directory;
     try {
       if (Platform.isIOS) {
         directory = await getApplicationDocumentsDirectory();
       } else {
         directory = Directory('/storage/emulated/0/Download');
         // Put file in global download folder, if for an unknown reason it didn't exist, we fallback
         // ignore: avoid_slow_async_io
         if (!await directory.exists()) directory = await getExternalStorageDirectory();
       }
     } catch (err, stack) {
       print("Cannot get download folder path");
     }
     return directory;
   }



/*
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("daphtech")),
        body: Container(
            child: Column(children: <Widget>[
              Expanded(
                child: Container(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: Uri.parse(_url)),
                    initialOptions: InAppWebViewGroupOptions(
                        crossPlatform: InAppWebViewOptions(
                          mediaPlaybackRequiresUserGesture: false,
                            javaScriptEnabled:true,
                        ),
                        ios: IOSInAppWebViewOptions(
                          allowsInlineMediaPlayback: true,
                        )),
                    androidOnPermissionRequest: (InAppWebViewController controller,
                        String origin, List<String> resources) async {
                      await Permission.camera.request();
                      return PermissionRequestResponse(
                          resources: resources,
                          action: PermissionRequestResponseAction.GRANT);
                    },
                  ),
                ),
              ),
            ])));
  }

 */
}

