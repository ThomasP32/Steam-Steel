import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/models/shop_item.dart';
import 'package:mobile/services/api_config.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class ShopService {
  factory ShopService() => _instance;
  ShopService._internal();
  static final ShopService _instance = ShopService._internal();

  String get _baseUrl => '${ApiConfig.baseUrl}/api/shop';
  final SocketService _socketService = SocketService();

  Stream<int> get moneyUpdates =>
      _socketService.listen<int>('userMoneyUpdated');

  Future<List<ShopItem>> getCatalog() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/catalog'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data
            .map((item) => ShopItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        DebugLogger.log(
          'Failed to load catalog: ${response.statusCode}',
          tag: 'ShopService',
        );
        return [];
      }
    } catch (e) {
      DebugLogger.log('Error loading catalog: $e', tag: 'ShopService');
      return [];
    }
  }

  Future<List<ShopItem>> getCatalogWithUserStatus(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/catalog/$userId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data
            .map((item) => ShopItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        DebugLogger.log(
          'Failed to load catalog with user status: ${response.statusCode}',
          tag: 'ShopService',
        );
        return [];
      }
    } catch (e) {
      DebugLogger.log(
        'Error loading catalog with user status: $e',
        tag: 'ShopService',
      );
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserItems(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user-items/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } else {
        DebugLogger.log(
          'Failed to load user items: ${response.statusCode}',
          tag: 'ShopService',
        );
        return [];
      }
    } catch (e) {
      DebugLogger.log('Error loading user items: $e', tag: 'ShopService');
      return [];
    }
  }

  Future<Map<String, dynamic>> purchaseItem(
    String userId,
    String itemId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/purchase'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'itemId': itemId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        DebugLogger.log(
          'Failed to purchase item: ${response.statusCode}',
          tag: 'ShopService',
        );
        return {'success': false, 'error': 'Failed to purchase item'};
      }
    } catch (e) {
      DebugLogger.log('Error purchasing item: $e', tag: 'ShopService');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> equipItem(String userId, String itemId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/equip'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'itemId': itemId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        DebugLogger.log(
          'Failed to equip item: ${response.statusCode}',
          tag: 'ShopService',
        );
        return {'success': false, 'error': 'Failed to equip item'};
      }
    } catch (e) {
      DebugLogger.log('Error equipping item: $e', tag: 'ShopService');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unequipItem(String userId, String itemId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/unequip'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'itemId': itemId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        DebugLogger.log(
          'Failed to unequip item: ${response.statusCode}',
          tag: 'ShopService',
        );
        return {'success': false, 'error': 'Failed to unequip item'};
      }
    } catch (e) {
      DebugLogger.log('Error unequipping item: $e', tag: 'ShopService');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getUserItemsByUsername(
    String username,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user-items-by-username/$username'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } else {
        DebugLogger.log(
          'Failed to load user items by username: ${response.statusCode}',
          tag: 'ShopService',
        );
        return [];
      }
    } catch (e) {
      DebugLogger.log(
        'Error loading user items by username: $e',
        tag: 'ShopService',
      );
      return [];
    }
  }
}
