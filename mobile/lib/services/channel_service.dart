import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/constants/chat_events.dart';
import 'package:mobile/models/channel.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:rxdart/rxdart.dart';

class ChannelService {
  factory ChannelService() => _instance;
  ChannelService._internal();
  static final ChannelService _instance = ChannelService._internal();

  static const String _activeChannelKey = 'active_channel_name';

  final ApiClient _apiClient = ApiClient();
  final SocketService _socketService = SocketService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final BehaviorSubject<List<Channel>> _availableChannelsSubject =
      BehaviorSubject<List<Channel>>.seeded([]);
  final BehaviorSubject<List<Channel>> _joinedChannelsSubject =
      BehaviorSubject<List<Channel>>.seeded([]);
  final BehaviorSubject<Channel?> _activeChannelSubject =
      BehaviorSubject<Channel?>.seeded(null);

  Stream<List<Channel>> get availableChannels$ =>
      _availableChannelsSubject.stream;
  Stream<List<Channel>> get joinedChannels$ => _joinedChannelsSubject.stream;
  Stream<Channel?> get activeChannel$ => _activeChannelSubject.stream;

  List<Channel> get availableChannels => _availableChannelsSubject.value;
  List<Channel> get joinedChannels => _joinedChannelsSubject.value;
  Channel? get activeChannel => _activeChannelSubject.value;

  StreamSubscription<dynamic>? _channelsListSub;
  StreamSubscription<dynamic>? _channelCreatedSub;
  StreamSubscription<dynamic>? _channelDeletedSub;
  StreamSubscription<dynamic>? _youJoinedChannelSub;
  StreamSubscription<dynamic>? _youLeftChannelSub;

  Future<void> init() async {
    await _setupSocketListeners();
    await loadChannels();

    final globalChannel = Channel(name: 'global', creator: 'System');

    final joined = List<Channel>.from(_joinedChannelsSubject.value);
    if (!joined.any((c) => c.name.toLowerCase() == 'global')) {
      joined.insert(0, globalChannel); // Insérer en premier
      _joinedChannelsSubject.add(joined);
    }

    if (_activeChannelSubject.value == null) {
      final savedChannelName = await _storage.read(key: _activeChannelKey);

      if (savedChannelName != null && savedChannelName.isNotEmpty) {
        final savedChannel = joined.firstWhere(
          (c) => c.name == savedChannelName,
          orElse: () => globalChannel,
        );
        setActiveChannel(savedChannel);
      } else {
        setActiveChannel(globalChannel);
      }
    }
  }

  Future<void> _setupSocketListeners() async {
    _channelsListSub = _socketService
        .listen<dynamic>(ChatEvents.channelsList)
        .listen((data) {
          if (data is List) {
            final channels =
                data
                    .map(
                      (json) => Channel.fromJson(json as Map<String, dynamic>),
                    )
                    .toList();
            _availableChannelsSubject.add(channels);
          }
        });

    _channelCreatedSub = _socketService
        .listen<dynamic>(ChatEvents.channelCreated)
        .listen((data) {
          DebugLogger.log('Channel created: $data');
          if (data is Map<String, dynamic>) {
            final channel = Channel.fromJson(data);
            final currentAvailable = List<Channel>.from(
              _availableChannelsSubject.value,
            );
            final joined = _joinedChannelsSubject.value;

            final alreadyExists =
                currentAvailable.any((c) => c.name == channel.name) ||
                joined.any((c) => c.name == channel.name);

            if (!alreadyExists) {
              currentAvailable.insert(0, channel);
              _availableChannelsSubject.add(currentAvailable);
            }
          }
        });

    _channelDeletedSub = _socketService
        .listen<dynamic>(ChatEvents.channelDeleted)
        .listen((data) {
          DebugLogger.log('Channel deleted: $data');
          if (data is Map<String, dynamic>) {
            final channelName = data['name'] as String?;
            if (channelName != null) {
              final current = List<Channel>.from(
                _availableChannelsSubject.value,
              )..removeWhere((c) => c.name == channelName);
              _availableChannelsSubject.add(current);

              final joined = List<Channel>.from(_joinedChannelsSubject.value)
                ..removeWhere((c) => c.name == channelName);
              _joinedChannelsSubject.add(joined);

              if (_activeChannelSubject.value?.name == channelName) {
                final globalChannel = joined.firstWhere(
                  (c) => c.name.toLowerCase() == 'global',
                  orElse: () => Channel(name: 'global', creator: 'System'),
                );
                setActiveChannel(globalChannel);
              }
            }
          }
        });

    _youJoinedChannelSub = _socketService
        .listen<dynamic>(ChatEvents.youJoinedChannel)
        .listen((data) {
          DebugLogger.log('You joined channel: $data');
          if (data is Map<String, dynamic>) {
            final channel = Channel.fromJson(data);

            final joined = List<Channel>.from(_joinedChannelsSubject.value);
            if (!joined.any((c) => c.name == channel.name)) {
              // Trouver l'index de global (devrait être 0)
              final globalIndex = joined.indexWhere(
                (c) => c.name.toLowerCase() == 'global',
              );
              if (globalIndex >= 0) {
                joined.insert(globalIndex + 1, channel);
              } else {
                joined.insert(0, channel);
              }
              _joinedChannelsSubject.add(joined);
            }

            final available = List<Channel>.from(
              _availableChannelsSubject.value,
            )..removeWhere((c) => c.name == channel.name);
            _availableChannelsSubject.add(available);

            setActiveChannel(channel);

            _socketService.send('joinChatRoom', channel.name);
            DebugLogger.log('Auto-joined chatroom: ${channel.name}');
          }
        });

    _youLeftChannelSub = _socketService
        .listen<dynamic>(ChatEvents.youLeftChannel)
        .listen((data) {
          DebugLogger.log('You left channel: $data');
          if (data is Map<String, dynamic>) {
            final channelName = data['channelName'] as String?;
            if (channelName != null) {
              final joinedList = _joinedChannelsSubject.value;
              final channelToLeave = joinedList.firstWhere(
                (c) => c.name == channelName,
                orElse: () => Channel(name: channelName, creator: ''),
              );

              final joined = List<Channel>.from(joinedList)
                ..removeWhere((c) => c.name == channelName);
              _joinedChannelsSubject.add(joined);

              if (channelName.toLowerCase() != 'global') {
                final available = List<Channel>.from(
                  _availableChannelsSubject.value,
                );
                if (!available.any((c) => c.name == channelName)) {
                  available.add(channelToLeave);
                  _availableChannelsSubject.add(available);
                }
              }

              _socketService.send('leaveChatRoom', channelName);

              if (_activeChannelSubject.value?.name == channelName) {
                final globalChannel = joinedList.firstWhere(
                  (c) => c.name.toLowerCase() == 'global',
                  orElse: () => Channel(name: 'global', creator: 'System'),
                );
                setActiveChannel(globalChannel);
              }
            }
          }
        });
  }

  Future<void> loadChannels() async {
    try {
      _socketService.send(ChatEvents.listChannels, <String, dynamic>{});
      DebugLogger.log('Requested channels list from server');

      final channels = await _apiClient.getChannels();
      _availableChannelsSubject.add(channels);
      DebugLogger.log('Loaded ${channels.length} channels from API');
    } on Exception catch (e) {
      DebugLogger.log('Error loading channels: $e');
    }
  }

  Future<void> createChannel(String name, String creator) async {
    try {
      await _apiClient.createChannel(name, creator);
      DebugLogger.log('Channel created: $name');

      _socketService.send(ChatEvents.createChannel, {
        'name': name,
        'creator': creator,
        'isPublic': true,
      });

      final newChannel = Channel(name: name, creator: creator);

      final available = List<Channel>.from(_availableChannelsSubject.value);
      if (!available.any((c) => c.name == name)) {
        available.insert(0, newChannel);
        _availableChannelsSubject.add(available);
      }
    } catch (e) {
      DebugLogger.log('Error creating channel: $e');
      rethrow;
    }
  }

  Future<void> deleteChannel(String name) async {
    try {
      await _apiClient.deleteChannel(name);
      DebugLogger.log('Channel deleted: $name');

      _socketService.send(ChatEvents.deleteChannel, {'name': name});

      final available = List<Channel>.from(_availableChannelsSubject.value)
        ..removeWhere((c) => c.name == name);
      _availableChannelsSubject.add(available);

      final joined = List<Channel>.from(_joinedChannelsSubject.value)
        ..removeWhere((c) => c.name == name);
      _joinedChannelsSubject.add(joined);

      if (_activeChannelSubject.value?.name == name) {
        final globalChannel = joined.firstWhere(
          (c) => c.name.toLowerCase() == 'global',
          orElse: () => Channel(name: 'global', creator: 'System'),
        );
        setActiveChannel(globalChannel);
      }
    } catch (e) {
      DebugLogger.log('Error deleting channel: $e');
      rethrow;
    }
  }

  void joinChannel(String channelName) {
    _socketService.send(ChatEvents.joinChannel, {'channelName': channelName});
    DebugLogger.log('Joining channel: $channelName');

    final available = List<Channel>.from(_availableChannelsSubject.value);
    final channelToJoin = available.firstWhere(
      (c) => c.name == channelName,
      orElse: () => Channel(name: channelName, creator: ''),
    );

    available.removeWhere((c) => c.name == channelName);
    _availableChannelsSubject.add(available);

    final joined = List<Channel>.from(_joinedChannelsSubject.value);
    if (!joined.any((c) => c.name == channelName)) {
      final globalIndex = joined.indexWhere(
        (c) => c.name.toLowerCase() == 'global',
      );
      if (globalIndex >= 0) {
        joined.insert(globalIndex + 1, channelToJoin);
      } else {
        joined.insert(0, channelToJoin);
      }
      _joinedChannelsSubject.add(joined);
    }

    setActiveChannel(channelToJoin);
  }

  void leaveChannel(String channelName) {
    _socketService.send(ChatEvents.leaveChannel, {'channelName': channelName});
    DebugLogger.log('Leaving channel: $channelName');

    final joined = List<Channel>.from(_joinedChannelsSubject.value);
    final channelToLeave = joined.firstWhere(
      (c) => c.name == channelName,
      orElse: () => Channel(name: channelName, creator: ''),
    );

    joined.removeWhere((c) => c.name == channelName);
    _joinedChannelsSubject.add(joined);

    if (channelName.toLowerCase() != 'global') {
      final available = List<Channel>.from(_availableChannelsSubject.value);
      if (!available.any((c) => c.name == channelName)) {
        available.add(channelToLeave);
        _availableChannelsSubject.add(available);
      }
    }

    _socketService.send('leaveChatRoom', channelName);

    if (_activeChannelSubject.value?.name == channelName) {
      final globalChannel = joined.firstWhere(
        (c) => c.name.toLowerCase() == 'global',
        orElse: () => Channel(name: 'global', creator: 'System'),
      );
      setActiveChannel(globalChannel);
    }
  }

  void setActiveChannel(Channel? channel) {
    final previousChannel = _activeChannelSubject.value;

    if (previousChannel != null && previousChannel.name != channel?.name) {
      _socketService.send('leaveChatRoom', previousChannel.name);
      DebugLogger.log('Left chatroom: ${previousChannel.name}');
    }

    _activeChannelSubject.add(channel);

    if (channel != null) {
      _storage.write(key: _activeChannelKey, value: channel.name);
      _socketService.send('joinChatRoom', channel.name);
      DebugLogger.log('Joined chatroom: ${channel.name}');
    }

    DebugLogger.log('Active channel set to: ${channel?.name}');
  }

  void createPartyChannel(String gameId) {
    final partyChannelName = 'partie-$gameId';
    final partyChannel = Channel(name: partyChannelName, creator: 'system');

    final currentJoined = List<Channel>.from(_joinedChannelsSubject.value);
    if (!currentJoined.any((c) => c.name == partyChannelName)) {
      final globalIndex = currentJoined.indexWhere(
        (c) => c.name.toLowerCase() == 'global',
      );
      if (globalIndex != -1) {
        currentJoined.insert(globalIndex + 1, partyChannel);
      } else {
        currentJoined.add(partyChannel);
      }
      _joinedChannelsSubject.add(currentJoined);

      _socketService.send(ChatEvents.joinChannel, {
        'channelName': partyChannelName,
      });

      setActiveChannel(partyChannel);

      DebugLogger.log('Party channel created and joined: $partyChannelName');
    }
  }

  Future<void> removeGameChannel(String gameId) async {
    final partyChannelName = 'partie-$gameId';

    final currentJoined = List<Channel>.from(_joinedChannelsSubject.value);
    final newJoined =
        currentJoined.where((c) => c.name != partyChannelName).toList();
    _joinedChannelsSubject.add(newJoined);

    if (_activeChannelSubject.value?.name == partyChannelName) {
      final globalChannel = currentJoined.firstWhere(
        (c) => c.name.toLowerCase() == 'global',
        orElse: () => Channel(name: 'global', creator: 'System'),
      );
      setActiveChannel(globalChannel);
    }

    _socketService.send(ChatEvents.leaveChannel, {
      'channelName': partyChannelName,
    });

    await Future.delayed(const Duration(milliseconds: 100));

    DebugLogger.log('Game channel removed: $partyChannelName');
  }

  bool isPartyChannel(String channelName) {
    return channelName.startsWith('partie-');
  }

  void dispose() {
    _channelsListSub?.cancel();
    _channelCreatedSub?.cancel();
    _channelDeletedSub?.cancel();
    _youJoinedChannelSub?.cancel();
    _youLeftChannelSub?.cancel();
    _availableChannelsSubject.close();
    _joinedChannelsSubject.close();
    _activeChannelSubject.close();
    _apiClient.dispose();
  }
}
