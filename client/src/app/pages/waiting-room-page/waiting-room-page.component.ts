import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { ChallengeComponent } from '@app/components/challenge/challenge.component';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { PlayersListComponent } from '@app/components/players-list/players-list.component';
import { ProfileModalComponent } from '@app/components/profile-modal/profile-modal.component';
import { VirtualMoneyComponent } from '@app/components/virtual-money/virtual-money.component';
import { ChannelService } from '@app/services/channel/channel.service';
import { CharacterService } from '@app/services/character/character.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { FriendsService } from '@app/services/friends/friends.service';
import { GameService } from '@app/services/game/game.service';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { TIME_LIMIT_DELAY, WaitingRoomParameters } from '@common/constants';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents, ToggleGameLockStateData } from '@common/events/game-creation.events';
import { Game, GameCtf, Player } from '@common/game';
import { Map, Mode } from '@common/map.types';
import { UserStatus } from '@common/user-friends';
import { firstValueFrom, Subscription } from 'rxjs';

@Component({
    selector: 'app-waiting-room-page',
    standalone: true,
    imports: [CommonModule, PlayersListComponent, ChatroomComponent, ProfileModalComponent, ChallengeComponent, VirtualMoneyComponent],
    templateUrl: './waiting-room-page.component.html',
    styleUrls: ['./waiting-room-page.component.scss'],
})
export class WaitingRoomPageComponent implements OnInit, OnDestroy {
    @ViewChild(PlayersListComponent, { static: false }) appPlayersListComponent!: PlayersListComponent;

    constructor(
        private readonly communicationMapService: CommunicationMapService,
        private readonly gameService: GameService,
        private readonly characterService: CharacterService,
        private readonly playerService: PlayerService,
        private readonly socketService: SocketService,
        private readonly route: ActivatedRoute,
        private readonly router: Router,
        private readonly mapConversionService: MapConversionService,
        private readonly channelService: ChannelService,
        private readonly friendsService: FriendsService,
    ) {
        this.communicationMapService = communicationMapService;
        this.gameService = gameService;
        this.characterService = characterService;
        this.playerService = playerService;
        this.socketService = socketService;
        this.route = route;
        this.router = router;
        this.mapConversionService = mapConversionService;
        this.channelService = channelService;
        this.friendsService = friendsService;
    }

    waitingRoomCode: string;
    mapName: string;
    socketSubscription: Subscription = new Subscription();
    isHost: boolean = false;
    playerPreview: string;
    playerName: string;
    isStartable: boolean = false;
    isGameLocked: boolean = false;
    counterInitialized: boolean = false;
    private gameInitializedProcessing: boolean = false;
    gameInitialized: boolean = false;
    hover: boolean = false;
    activePlayers: Player[] = [];
    showExitModal: boolean = false;
    dialogBoxMessage: string;
    numberOfPlayers: number;
    maxPlayers: number;
    showProfileModal: boolean = false;
    isChatVisible: boolean = false;
    gameSettings: { isFastElimination: boolean; isDropInOut: boolean; isFriendsOnly: boolean; entryFee: number } = {
        isFastElimination: false,
        isDropInOut: false,
        isFriendsOnly: false,
        entryFee: 0,
    };

    async ngOnInit(): Promise<void> {
        if (!this.socketService.isSocketAlive()) {
            this.ngOnDestroy();
            this.characterService.resetCharacterAvailability();

            this.socketService.disconnect();
            this.router.navigate(['/main-menu']);
            return;
        }

        const player = this.playerService.player;
        this.playerPreview = this.characterService.getAvatarPreview(player.avatar);
        this.playerName = player.name;

        this.listenToSocketMessages();
        if (this.router.url.includes('host')) {
            this.isHost = true;
            this.getMapName();
            this.generateRandomNumber();
            if (window.history.state?.gameSettings) {
                this.gameSettings = window.history.state.gameSettings;
            }
            await this.createNewGame(this.mapName);
        } else {
            this.waitingRoomCode = this.route.snapshot.params['gameId'];
        }

        if (!this.isHost) {
            this.socketService.sendMessage(GameCreationEvents.GetGameData, this.waitingRoomCode);
            this.socketService.sendMessage(GameCreationEvents.GetPlayers, this.waitingRoomCode);
        }

        this.channelService.createPartyChannel(this.waitingRoomCode);
    }

    generateRandomNumber(): void {
        this.waitingRoomCode = Math.floor(
            WaitingRoomParameters.MIN_CODE + Math.random() * (WaitingRoomParameters.MAX_CODE - WaitingRoomParameters.MIN_CODE + 1),
        ).toString();
    }

    get player(): Player {
        return this.playerService.player;
    }

    async createNewGame(mapName: string): Promise<void> {
        const map: Map = await firstValueFrom(this.communicationMapService.basicGet<Map>(`map/${mapName}`));
        let newGame: Game | GameCtf;
        if (map.mode === Mode.Ctf) {
            newGame = this.gameService.createNewCtfGame(map, this.waitingRoomCode, this.gameSettings);
        } else {
            newGame = this.gameService.createNewGame(map, this.waitingRoomCode, this.gameSettings);
        }

        this.socketService.sendMessage(GameCreationEvents.CreateGame, newGame);
    }

    exitGame(): void {
        this.gameInitializedProcessing = false;
        this.gameInitialized = false;
        
        this.channelService.removePartyChannel(this.waitingRoomCode);
        this.socketService.sendMessage(GameCreationEvents.LeaveGame, this.waitingRoomCode);
        this.socketService.sendMessage(FriendsEvents.UpdateUserStatus, { status: UserStatus.Online });

        setTimeout(() => {
            this.characterService.resetCharacterAvailability();
            this.socketService.disconnect();
            this.router.navigate(['/main-menu'], { state: {} });
        }, 100);
    }

    getMapName(): void {
        const name = this.route.snapshot.params['mapName'];
        if (!name) {
            this.router.navigate(['/create-game']);
        } else {
            this.mapName = name;
        }
    }

    startGame(): void {
        this.socketService.sendMessage(GameCreationEvents.InitializeGame, this.waitingRoomCode);
    }

    listenToSocketMessages(): void {
        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameCreationError).subscribe((errorMessage) => {
                this.dialogBoxMessage = errorMessage;
                this.showExitModal = true;
                setTimeout(() => {
                    this.exitGame();
                }, TIME_LIMIT_DELAY);
            }),
        );

        if (!this.isHost) {
            this.socketSubscription.add(
                this.socketService.listen(GameCreationEvents.GameClosed).subscribe(() => {
                    const currentGameId = this.waitingRoomCode || this.route.snapshot.params['gameId'];
                    if (currentGameId && !this.isHost && this.router.url.includes('waiting-room')) {
                        this.dialogBoxMessage = "L'hôte de la partie a quitté.";
                        this.showExitModal = true;
                        setTimeout(() => {
                            this.exitGame();
                        }, TIME_LIMIT_DELAY);
                    }
                }),
            );
            this.socketSubscription.add(
                this.socketService.listen<boolean>(GameCreationEvents.GameLockToggled).subscribe((isLocked) => {
                    this.isGameLocked = isLocked;
                }),
            );
        }
        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameInitialized).subscribe((game) => {
                if (this.gameInitializedProcessing) {
                    console.warn('[WaitingRoom] IGNORING GameInitialized - already processing initialization');
                    return;
                }
                
                if (game.id !== this.waitingRoomCode) {
                    console.warn('[WaitingRoom] IGNORING GameInitialized for different game. Event:', game.id, 'vs My game:', this.waitingRoomCode);
                    return;
                }

                this.gameInitializedProcessing = true;

                this.gameService.setGame(game);
                game.players.forEach((player) => {
                    if (player.socketId === this.player.socketId) {
                        this.playerService.setPlayer(player);
                    }
                });
                this.gameInitialized = true;
                this.navigateToGamePage();
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameCreationEvents.CurrentPlayers).subscribe((players: Player[]) => {
                this.activePlayers = players;
                this.numberOfPlayers = players.length;
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.CurrentGame).subscribe((game) => {
                if (game && game.mapSize) {
                    if (this.isHost) {
                        this.maxPlayers = this.mapConversionService.getMaxPlayers(game.mapSize.x);
                    } else {
                        this.mapName = game.name;
                        this.maxPlayers = this.mapConversionService.getMaxPlayers(game.mapSize.x);
                        if (game.settings) {
                            this.gameSettings = game.settings;
                        }
                    }
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameCreationEvents.PlayerJoined).subscribe((players: Player[]) => {
                this.activePlayers = players;
                this.numberOfPlayers = players.length;

                if (this.isHost) {
                    this.socketService.sendMessage(GameCreationEvents.IfStartable, this.waitingRoomCode);
                }
                if (this.numberOfPlayers === this.maxPlayers) {
                    const toggleGameLockStateData: ToggleGameLockStateData = { isLocked: true, gameId: this.waitingRoomCode };
                    this.socketService.sendMessage(GameCreationEvents.ToggleGameLockState, toggleGameLockStateData);
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen(GameCreationEvents.PlayerKicked).subscribe(() => {
                this.dialogBoxMessage = 'Vous avez été exclu';
                this.showExitModal = true;
                setTimeout(() => {
                    this.exitGame();
                }, TIME_LIMIT_DELAY);
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameCreationEvents.PlayerLeft).subscribe((players: Player[]) => {
                if (this.isHost) {
                    this.isStartable = false;
                    this.socketService.sendMessage(GameCreationEvents.IfStartable, this.waitingRoomCode);
                }
                this.activePlayers = players;
                this.numberOfPlayers = players.length;
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen(GameCreationEvents.IsStartable).subscribe(() => {
                this.isStartable = true;
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameCreated).subscribe(() => {
                this.socketService.sendMessage(GameCreationEvents.GetGameData, this.waitingRoomCode);
                this.socketService.sendMessage(GameCreationEvents.GetPlayers, this.waitingRoomCode);
            }),
        );
    }

    toggleHover(state: boolean): void {
        this.hover = state;
    }

    toggleGameLockState(): void {
        this.isGameLocked = !this.isGameLocked;
        const toggleGameLockStateData: ToggleGameLockStateData = { isLocked: this.isGameLocked, gameId: this.waitingRoomCode };
        this.socketService.sendMessage(GameCreationEvents.ToggleGameLockState, toggleGameLockStateData);
    }

    isGameMaxed(): boolean {
        return this.numberOfPlayers === this.maxPlayers;
    }

    navigateToGamePage() {
        console.log('[WaitingRoom] navigateToGamePage called for game:', this.waitingRoomCode);
        console.log('[WaitingRoom] Player:', this.player.name, 'Socket ID:', this.player.socketId);
        this.router.navigate([`/game/${this.waitingRoomCode}/${this.mapName}`], {
            state: { player: this.player, gameId: this.waitingRoomCode },
        });
    }

    openProfileModal(): void {
        this.showProfileModal = true;
    }

    closeProfileModal(): void {
        this.showProfileModal = false;
    }

    inviteAllOnlineFriends(): void {
        if (this.waitingRoomCode && this.mapName) {
            this.friendsService.inviteAllOnlineFriends(this.waitingRoomCode, this.mapName);
        }
    }

    ngOnDestroy(): void {
        this.gameInitializedProcessing = false;
        this.gameInitialized = false;
        
        if (this.socketSubscription) {
            this.socketSubscription.unsubscribe();
        }
        
        this.socketService.removeListener(GameCreationEvents.GameInitialized);
        this.socketService.removeListener(GameCreationEvents.IsStartable);
        this.socketService.removeListener(GameCreationEvents.PlayerJoined);
        
    }
}
