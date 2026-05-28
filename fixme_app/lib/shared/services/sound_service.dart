import 'package:audioplayers/audioplayers.dart';

class SoundService {

  ////////////////////////////////////////////////////////////
  /// PLAYERS
  ////////////////////////////////////////////////////////////

  static final AudioPlayer _sendPlayer =
      AudioPlayer();

  static final AudioPlayer _messagePlayer =
      AudioPlayer();

  ////////////////////////////////////////////////////////////
  /// SEND WHOOSH
  ////////////////////////////////////////////////////////////

  static Future<void> send() async {

    try {

      await _sendPlayer.stop();

      await _sendPlayer.play(

        AssetSource(
          'sounds/send.mp3',
        ),

        volume: 1.0,
      );

      print(
        "SEND SOUND PLAYED",
      );

    } catch (e) {

      print(
        "SEND SOUND ERROR => $e",
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// RECEIVE SOUND
  ////////////////////////////////////////////////////////////

  static Future<void> message() async {

    try {

      await _messagePlayer.stop();

      await _messagePlayer.play(

        AssetSource(
          'sounds/message.mp3',
        ),

        volume: 1.0,
      );

      print(
        "MESSAGE SOUND PLAYED",
      );

    } catch (e) {

      print(
        "MESSAGE SOUND ERROR => $e",
      );
    }
  }
}