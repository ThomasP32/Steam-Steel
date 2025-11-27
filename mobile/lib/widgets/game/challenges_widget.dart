import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/challenge.dart';
import 'package:mobile/services/challenge_service.dart';

class ChallengesWidget extends StatefulWidget {
  const ChallengesWidget({
    super.key,
    this.showInfoButton = true,
    this.isCompact = false,
  });

  final bool showInfoButton;
  final bool isCompact;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ValueListenableBuilder<PublicChallengeView?>(
        valueListenable: _challengeService.challengeNotifier,
        builder: (context, challenge, _) {
          if (challenge == null) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: widget.isCompact ? null : 270,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.75),
                border: Border.all(
                  color:
                      challenge.completed
                          ? Colors.green
                          : AppColors.accentHighlight(context),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isCompact)
                    _buildCompactHeader(challenge, isDark)
                  else
                    _buildExpandedHeader(challenge, isDark),
                  if (_showInfoTooltip) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Complétez ce défi pour obtenir la récompense!',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    challenge.description,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                    ),
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
                                                AppColors.accentHighlight(
                                                  context,
                                                ).withValues(alpha: 0.7),
                                                AppColors.accentHighlight(
                                                  context,
                                                ),
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
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
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

  Widget _buildCompactHeader(PublicChallengeView challenge, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                challenge.title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFED4E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC107), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'lib/assets/icons/money.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.monetization_on,
                        size: 16,
                        color: Color(0xFF7D4F00),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.reward}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7D4F00),
                      shadows: [
                        Shadow(
                          color: Colors.white54,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.showInfoButton) ...[
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showInfoTooltip = !_showInfoTooltip;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.accentHighlight(context),
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
      ],
    );
  }

  Widget _buildExpandedHeader(PublicChallengeView challenge, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  challenge.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
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
                    decoration: BoxDecoration(
                      color: AppColors.accentHighlight(context),
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

        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFED4E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'lib/assets/icons/money.png',
                width: 16,
                height: 16,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.monetization_on,
                    size: 16,
                    color: Color(0xFF7D4F00),
                  );
                },
              ),
              const SizedBox(width: 4),
              Text(
                '${challenge.reward}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7D4F00),
                  shadows: [
                    Shadow(
                      color: Colors.white54,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
