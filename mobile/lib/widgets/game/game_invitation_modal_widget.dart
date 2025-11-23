import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';

class GameInvitation {
  const GameInvitation({
    required this.gameId,
    required this.gameName,
    required this.inviterUsername,
    required this.inviterName,
  });

  factory GameInvitation.fromJson(Map<String, dynamic> json) {
    final gameIdValue = json['gameId'];
    final gameId =
        gameIdValue is int
            ? gameIdValue.toString()
            : (gameIdValue as String? ?? '');

    return GameInvitation(
      gameId: gameId,
      gameName: json['gameName'] as String? ?? '',
      inviterUsername: json['inviterUsername'] as String? ?? '',
      inviterName: json['inviterName'] as String? ?? '',
    );
  }

  final String gameId;
  final String gameName;
  final String inviterUsername;
  final String inviterName;
}

class GameInvitationModalWidget extends StatelessWidget {
  const GameInvitationModalWidget({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
    required this.onClose,
    super.key,
  });

  final GameInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(minWidth: 400, maxWidth: 500),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient:
                isDark
                    ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2c3e50), Color(0xFF34495e)],
                    )
                    : null,
            color: isDark ? null : Colors.white,
            border: Border.all(
              color: AppColors.accentHighlight(context),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Invitation de partie',
                      style: TextStyle(
                        color: AppColors.accentHighlight(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Press Start 2P',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color:
                              isDark ? const Color(0xFFecf0f1) : Colors.black87,
                          fontSize: 16,
                          height: 1.5,
                          fontFamily: 'Press Start 2P',
                        ),
                        children: [
                          TextSpan(
                            text: invitation.inviterName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: ' vous invite à rejoindre une partie',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      'Partie: ${invitation.gameName}',
                      style: TextStyle(
                        color: AppColors.accentHighlight(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onReject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFe74c3c), // Red
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Refuser',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Press Start 2P',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27ae60), // Green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Rejoindre',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Press Start 2P',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
