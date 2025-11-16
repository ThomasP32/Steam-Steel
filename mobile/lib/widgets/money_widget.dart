import 'package:flutter/material.dart';
import 'package:mobile/services/auth_service.dart';

class MoneyWidget extends StatefulWidget {
  const MoneyWidget({super.key, this.compact = false});
  final bool compact;

  @override
  State<MoneyWidget> createState() => _MoneyWidgetState();
}

class _MoneyWidgetState extends State<MoneyWidget> {
  final AuthService _authService = AuthService();
  int _currentMoney = 0;

  @override
  void initState() {
    super.initState();
    _loadMoney();
    _authService.notifier.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    _authService.notifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _loadMoney() {
    final user = _authService.notifier.value;
    if (user != null) {
      setState(() {
        _currentMoney = user.virtualMoney;
      });
    }
  }

  void _onUserUpdated() {
    final user = _authService.notifier.value;
    if (user != null && mounted) {
      setState(() {
        _currentMoney = user.virtualMoney;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = widget.compact ? 8.0 : 16.0;
    final verticalPadding = widget.compact ? 4.0 : 8.0;
    final borderRadius = widget.compact ? 12.0 : 20.0;
    final iconSize = widget.compact ? 16.0 : 20.0;
    final fontSize = widget.compact ? 10.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFED4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFFFC107), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/assets/icons/money.png',
            width: iconSize,
            height: iconSize,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.monetization_on,
                size: iconSize,
                color: const Color(0xFF7D4F00),
              );
            },
          ),
          SizedBox(width: widget.compact ? 4.0 : 6.0),
          Text(
            '$_currentMoney',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF7D4F00),
              shadows: const [
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
    );
  }
}
