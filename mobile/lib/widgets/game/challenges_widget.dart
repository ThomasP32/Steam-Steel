import 'package:flutter/material.dart';
import 'package:mobile/common/challenge.dart';
import 'package:mobile/services/challenge_service.dart';

class ChallengesWidget extends StatefulWidget {
  const ChallengesWidget({super.key, this.showInfoButton = true});

  final bool showInfoButton;

  @override
  State<ChallengesWidget> createState() => _ChallengesWidgetState();
}

class _ChallengesWidgetState extends State<ChallengesWidget> {
  final ChallengeService _challengeService = ChallengeService();
  bool _showInfoTooltip = false;

  @override
  void initState() {
    super.initState();
    _challengeService.initialize();
  }

  int _getProgressPercentage(PublicChallengeView challenge) {
    return (challenge.progress * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<PublicChallengeView?>(
        valueListenable: _challengeService.challengeNotifier,
        builder: (context, challenge, _) {
          if (challenge == null) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: 270,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    challenge.completed
                        ? const Color(0xFF2C5E3A).withValues(alpha: 0.95)
                        : const Color(0xFF2C3E50).withValues(alpha: 0.95),
                border: Border.all(
                  color: challenge.completed ? Colors.green : Colors.orange,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                challenge.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.showInfoButton) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showInfoTooltip = !_showInfoTooltip;
                                  });
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'i',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Image.asset(
                            'lib/assets/icons/money.png',
                            width: 16,
                            height: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${challenge.reward}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_showInfoTooltip) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Complétez ce défi pour obtenir la récompense!',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    challenge.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                Container(
                                  height: 24,
                                  width:
                                      constraints.maxWidth * challenge.progress,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors:
                                          challenge.completed
                                              ? [
                                                Colors.green.shade400,
                                                Colors.green.shade600,
                                              ]
                                              : [
                                                Colors.orange.shade400,
                                                Colors.orange.shade600,
                                              ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getProgressPercentage(challenge)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (challenge.completed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Défi Complété!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
