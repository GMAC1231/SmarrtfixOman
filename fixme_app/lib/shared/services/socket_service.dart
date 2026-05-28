import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart'
    as IO;

import 'sound_service.dart';

class SocketService {

  static IO.Socket? socket;

  static bool _connected = false;

  ////////////////////////////////////////////////////////////
  /// CONNECT
  ////////////////////////////////////////////////////////////

  static Future<void> connect(
    String myUid,
  ) async {

    try {

      if (_connected) return;

      socket = IO.io(

        "http://192.168.100.15:5000",

        IO.OptionBuilder()

            .setTransports(
              ['websocket']
            )

            .disableAutoConnect()

            .enableReconnection()

            .build(),
      );

      socket!.connect();

      ////////////////////////////////////////////////////////
      /// CONNECTED
      ////////////////////////////////////////////////////////

      socket!.onConnect((_) {

        debugPrint(
          "SOCKET CONNECTED",
        );

        _connected = true;

        //////////////////////////////////////////////////////
        /// REGISTER USER
        //////////////////////////////////////////////////////

        socket!.emit(
          "register",
          {
            "uid": myUid,
          },
        );
      });

      ////////////////////////////////////////////////////////
      /// RECEIVE SOUND EVENT
      ////////////////////////////////////////////////////////

      socket!.on(

        "play_sound",

        (data) async {

          debugPrint(
            "PLAY SOUND EVENT => $data",
          );

          try {

            if (

                data["receiver_id"] ==
                    myUid

            ) {

              //////////////////////////////////////////////////
              /// PLAY RECEIVE SOUND
              //////////////////////////////////////////////////

              await SoundService.message();

              debugPrint(
                "RECEIVE SOUND PLAYED",
              );
            }

          } catch (e) {

            debugPrint(
              "SOUND PLAY ERROR => $e",
            );
          }
        },
      );

      ////////////////////////////////////////////////////////
      /// ERRORS
      ////////////////////////////////////////////////////////

      socket!.onConnectError((e) {

        debugPrint(
          "SOCKET CONNECT ERROR => $e",
        );
      });

      socket!.onError((e) {

        debugPrint(
          "SOCKET ERROR => $e",
        );
      });

      socket!.onDisconnect((_) {

        debugPrint(
          "SOCKET DISCONNECTED",
        );

        _connected = false;
      });

    } catch (e) {

      debugPrint(
        "SOCKET INIT ERROR => $e",
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////

  static void dispose() {

    socket?.disconnect();

    socket?.dispose();

    socket = null;

    _connected = false;
  }
}