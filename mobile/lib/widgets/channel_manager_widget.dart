import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/models/channel.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class ChannelManagerWidget extends StatefulWidget {
  const ChannelManagerWidget({
    required this.userName,
    this.onRegisterCloseCallback,
    this.onDropdownOpened,
    super.key,
  });

  final String userName;
  final void Function(VoidCallback)? onRegisterCloseCallback;
  final VoidCallback? onDropdownOpened;

  @override
  State<ChannelManagerWidget> createState() => _ChannelManagerWidgetState();
}

class _ChannelManagerWidgetState extends State<ChannelManagerWidget> {
  final ChannelService _channelService = ChannelService();
  final TextEditingController _searchAvailableController =
      TextEditingController();
  final TextEditingController _searchJoinedController = TextEditingController();
  final TextEditingController _createChannelController =
      TextEditingController();
  final ScrollController _availableScrollController = ScrollController();
  final ScrollController _joinedScrollController = ScrollController();

  bool _showAvailable = false;
  bool _showJoined = false;
  bool _showCreateModal = false;
  bool _showDeleteModal = false;
  String _channelToDelete = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _channelService.loadChannels);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterCloseCallback?.call(closeDropdowns);
    });
  }

  void closeDropdowns() {
    if (mounted) {
      setState(() {
        _showAvailable = false;
        _showJoined = false;
      });
    }
  }

  @override
  void dispose() {
    _searchAvailableController.dispose();
    _searchJoinedController.dispose();
    _createChannelController.dispose();
    _availableScrollController.dispose();
    _joinedScrollController.dispose();
    super.dispose();
  }

  List<Channel> _filterAvailableChannels(List<Channel> channels) {
    final joined = _channelService.joinedChannels;
    final joinedNames = joined.map((c) => c.name.toLowerCase()).toSet();

    final filtered =
        channels.where((c) {
          final name = c.name.toLowerCase();
          return name != 'global' &&
              !_channelService.isPartyChannel(c.name) &&
              !joinedNames.contains(name);
        }).toList();

    final query = _searchAvailableController.text.toLowerCase();
    if (query.isEmpty) return filtered;
    return filtered.where((c) => c.name.toLowerCase().contains(query)).toList();
  }

  List<Channel> _filterJoinedChannels(List<Channel> channels) {
    final globalChannel = Channel(name: 'global', creator: 'System');

    final query = _searchJoinedController.text.toLowerCase();

    if (query.isEmpty) {
      final partyChannels =
          channels
              .where((c) => _channelService.isPartyChannel(c.name))
              .toList();
      final otherChannels =
          channels
              .where(
                (c) =>
                    c.name.toLowerCase() != 'global' &&
                    !_channelService.isPartyChannel(c.name),
              )
              .toList();

      return [globalChannel, ...partyChannels, ...otherChannels];
    }

    final filtered = <Channel>[];
    if ('global'.contains(query)) {
      filtered.add(globalChannel);
    }

    final matchingParty = channels.where(
      (c) =>
          _channelService.isPartyChannel(c.name) &&
          c.name.toLowerCase().contains(query),
    );
    filtered
      ..addAll(matchingParty)
      ..addAll(
        channels.where(
          (c) =>
              c.name.toLowerCase() != 'global' &&
              !_channelService.isPartyChannel(c.name) &&
              c.name.toLowerCase().contains(query),
        ),
      );
    return filtered;
  }

  void _toggleCreateModal() {
    setState(() {
      _showCreateModal = !_showCreateModal;
      if (!_showCreateModal) {
        _createChannelController.clear();
      }
    });
  }

  Future<void> _createChannel() async {
    final name = _createChannelController.text.trim();
    if (name.isEmpty) return;

    if (name.length < 3 || name.length > 20) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Le nom du salon doit contenir entre 3 et 20 caractères',
          ),
        );
      }
      return;
    }

    final allChannels = [
      ..._channelService.availableChannels,
      ..._channelService.joinedChannels,
    ];

    final channelExists = allChannels.any(
      (channel) => channel.name.toLowerCase() == name.toLowerCase(),
    );

    if (channelExists) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Ce nom de salon est déjà utilisé',
          ),
        );
      }
      return;
    }

    try {
      await _channelService.createChannel(name, widget.userName);
      _toggleCreateModal();

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.success(message: 'Salon "$name" créé avec succès'),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(message: 'Erreur lors de la création: $e'),
        );
      }
    }
  }

  void _confirmDeleteChannel(String name) {
    setState(() {
      _channelToDelete = name;
      _showDeleteModal = true;
    });
  }

  void _toggleDeleteModal() {
    setState(() {
      _showDeleteModal = !_showDeleteModal;
      if (!_showDeleteModal) {
        _channelToDelete = '';
      }
    });
  }

  Future<void> _confirmDelete() async {
    await _deleteChannel(_channelToDelete);
    _toggleDeleteModal();
  }

  Future<void> _deleteChannel(String name) async {
    try {
      await _channelService.deleteChannel(name);

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.success(message: 'Salon "$name" supprimé avec succès'),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(message: 'Erreur lors de la suppression: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final minHeight = (_showCreateModal || _showDeleteModal) ? 250.0 : 0.0;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _buildAvailableDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildJoinedDropdown()),
                  ],
                ),
              ),

              _buildAvailablePanel(),
              _buildJoinedPanel(),
            ],
          ),

          if (_showCreateModal) _buildCreateModal(),

          if (_showDeleteModal) _buildDeleteModal(),
        ],
      ),
    );
  }

  Widget _buildAvailableDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        widget.onDropdownOpened?.call();

        setState(() {
          _showAvailable = !_showAvailable;
          if (_showAvailable) _showJoined = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3B3F46) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showAvailable ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: isDark ? Colors.white : Colors.black,
              size: 16,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Salons disponibles',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 8.5,
                  fontFamily: 'Press Start 2P',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinedDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        widget.onDropdownOpened?.call();

        setState(() {
          _showJoined = !_showJoined;
          if (_showJoined) _showAvailable = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3B3F46) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showJoined ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: isDark ? Colors.white : Colors.black,
              size: 16,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Salons rejoints',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 8.5,
                  fontFamily: 'Press Start 2P',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailablePanel() {
    if (!_showAvailable) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF2E3136)
                : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2124) : Colors.grey.shade300,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de recherche avec icône + et recherche
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: AppColors.accentHighlight(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchAvailableController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 11,
                        fontFamily: 'Press Start 2P',
                      ),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un salon...',
                        hintStyle: TextStyle(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.5),
                          fontSize: 9,
                          fontFamily: 'Press Start 2P',
                        ),
                        filled: true,
                        fillColor:
                            isDark
                                ? const Color(0xFF1E2124)
                                : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: AppColors.accentHighlight(context),
                    ),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _toggleCreateModal,
                  ),
                ],
              ),
            ),

            StreamBuilder<List<Channel>>(
              stream: _channelService.availableChannels$,
              builder: (context, snapshot) {
                final channels = _filterAvailableChannels(snapshot.data ?? []);

                if (channels.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Aucun salon disponible',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 8,
                        fontFamily: 'Press Start 2P',
                      ),
                    ),
                  );
                }

                final maxHeight = channels.length > 2 ? 100.0 : null;

                return Container(
                  constraints:
                      maxHeight != null
                          ? BoxConstraints(maxHeight: maxHeight)
                          : null,
                  child: Scrollbar(
                    controller: _availableScrollController,
                    thumbVisibility: channels.length > 2,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: SingleChildScrollView(
                      controller: _availableScrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            channels
                                .map(
                                  (channel) => _buildChannelItem(
                                    channel,
                                    isJoined: false,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinedPanel() {
    if (!_showJoined) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF2E3136)
                : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2124) : Colors.grey.shade300,
        ),
      ),
      child: StreamBuilder<List<Channel>>(
        stream: _channelService.joinedChannels$,
        builder: (context, snapshot) {
          final channels = _filterJoinedChannels(snapshot.data ?? []);

          if (channels.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Aucun salon rejoint',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 8,
                  fontFamily: 'Press Start 2P',
                ),
              ),
            );
          }

          final maxHeight = channels.length > 2 ? 100.0 : null;

          return Container(
            constraints:
                maxHeight != null ? BoxConstraints(maxHeight: maxHeight) : null,
            child: Scrollbar(
              controller: _joinedScrollController,
              thumbVisibility: channels.length > 2,
              thickness: 6,
              radius: const Radius.circular(3),
              child: SingleChildScrollView(
                controller: _joinedScrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      channels
                          .map(
                            (channel) =>
                                _buildChannelItem(channel, isJoined: true),
                          )
                          .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelItem(Channel channel, {required bool isJoined}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _channelService.activeChannel?.name == channel.name;
    final isGlobal = channel.name.toLowerCase() == 'global';
    final isPartyChannel = _channelService.isPartyChannel(channel.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:
            isActive
                ? AppColors.accentHighlight(context)
                : isDark
                ? const Color(0xFF3B3F46)
                : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () {
          if (isJoined) {
            _channelService.setActiveChannel(channel);
            setState(() {
              _showAvailable = false;
              _showJoined = false;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Nom du channel
              Expanded(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color:
                        isActive
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black),
                    fontSize: 10,
                  ),
                ),
              ),
              // Actions à droite
              _buildChannelActions(channel, isJoined, isGlobal, isPartyChannel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelActions(
    Channel channel,
    bool isJoined,
    bool isGlobal,
    bool isPartyChannel,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isJoined) ...[
          IconButton(
            icon: const Icon(Icons.login, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Rejoindre',
            onPressed: () => _channelService.joinChannel(channel.name),
          ),
          if (!isGlobal && !isPartyChannel) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Supprimer',
              onPressed: () => _confirmDeleteChannel(channel.name),
            ),
          ],
        ],
        if (isJoined && !isGlobal && !isPartyChannel) ...[
          IconButton(
            icon: const Icon(Icons.logout, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Quitter',
            onPressed: () => _channelService.leaveChannel(channel.name),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDeleteChannel(channel.name),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {}, // Prevent closing on background tap
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap propagation
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E3136) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accentHighlight(context),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Créer un salon',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _createChannelController,
                      autofocus: true,
                      maxLength: 20,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontFamily: 'Press Start 2P',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nom du salon',
                        labelStyle: TextStyle(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.black.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontFamily: 'Press Start 2P',
                        ),
                        filled: true,
                        fillColor:
                            isDark
                                ? const Color(0xFF1E2124)
                                : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _toggleCreateModal,
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 10,
                              fontFamily: 'Press Start 2P',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _createChannel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentHighlight(context),
                          ),
                          child: const Text(
                            'Créer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Press Start 2P',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {}, // Prevent closing on background tap
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap propagation
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E3136) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmer la suppression',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Press Start 2P',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Voulez-vous vraiment supprimer le salon "$_channelToDelete" ?',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 10,
                        fontFamily: 'Press Start 2P',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _toggleDeleteModal,
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 10,
                              fontFamily: 'Press Start 2P',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _confirmDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Press Start 2P',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
