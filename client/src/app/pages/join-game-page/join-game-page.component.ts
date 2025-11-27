import { Component, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { ErrorMessageComponent } from '@app/components/error-message-component/error-message.component';
import { GamePreviewComponent } from '@app/components/game-preview/game-preview.component';
import { JoinGameModalComponent } from '@app/components/join-game-modal/join-game-modal.component';
import { VirtualMoneyComponent } from '@app/components/virtual-money/virtual-money.component';
import { AudioService } from '@app/services/audio/audio.service';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { FriendsService } from '@app/services/friends/friends.service';
import { GameService } from '@app/services/game/game.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { DEFAULT_ACTIONS, DEFAULT_ATTACK, DEFAULT_DEFENSE, DEFAULT_EVASIONS, DEFAULT_HP, DEFAULT_SPEED, ProfileType } from '@common/constants';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents, JoinGameData } from '@common/events/game-creation.events';
import { Avatar, Bonus, Game, Player, Specs } from '@common/game';
import { Friend } from '@common/user-friends';
import { Subject, Subscription, takeUntil } from 'rxjs';

@Component({
    selector: 'app-join-game-page',
    standalone: true,
    imports: [ChatroomComponent, JoinGameModalComponent, ErrorMessageComponent, GamePreviewComponent, VirtualMoneyComponent],
    templateUrl: './join-game-page.component.html',
    styleUrl: './join-game-page.component.scss',
})
export class JoinGamePageComponent implements OnInit, OnDestroy {
    @ViewChild(ErrorMessageComponent) errorModal!: ErrorMessageComponent;

    isChatVisible: boolean = false;
    currentUsername: string = '';
    currentUserId: string = '';
    games: Game;
    activeGames: Game[] = [];
    friendIds: Friend[] = [];
    socketSubscription: Subscription = new Subscription();
    errorMessage: string | null = null;

    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly router: Router,
        private readonly authService: AuthService,
        private readonly socketService: SocketService,
        private readonly playerService: PlayerService,
        private readonly gameService: GameService,
        private readonly friendsService: FriendsService,
        private readonly audioService: AudioService,
    ) {
        this.router = router;
        this.authService = authService;
        this.socketService = socketService;
        this.playerService = playerService;
        this.gameService = gameService;
        this.friendsService = friendsService;
        this.audioService = audioService;
    }

    async ngOnInit(): Promise<void> {
        try {
            await this.authService.getUserInfo();
        } catch (error) {
            console.error('Erreur lors de la récupération des informations utilisateur:', error);
        }
        await this.loadUserInfo();
        console.log('INIT join game and load games');

        // Listen for games response
        this.socketService
            .listen<Game[]>(GameCreationEvents.GetGames)
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe((gameRooms: Game[]) => {
                this.activeGames = gameRooms.filter((game) => this.canSeeGame(game));
            });

        // Request games
        await this.loadGames();

        this.socketService
            .listen<void>(GameCreationEvents.GameListUpdated)
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe(() => {
                this.loadGames();
            });

        this.configureJoinGameSocketFeatures();
        this.friendIds = await this.friendsService.getFriends();
    }

    private async loadUserInfo(): Promise<void> {
        const userInfo = await this.authService.getUserInfo();
        this.currentUsername = userInfo.user.username;
        this.currentUserId = userInfo.user.id;
    }

    private async loadGames(): Promise<void> {
        this.socketService.sendMessage(GameCreationEvents.GetGames);
    }

    canSeeGame(game: Game): boolean {
        // If game has no settings or is not friends-only, show it to everyone
        console.log('GAME object in join game: ', game);
        if (!game.settings || !game.settings.isFriendsOnly) return true;

        const hostId = game.hostSocketId;
        const hostPlayer = game.players.find((plyr) => plyr.socketId === hostId);

        // Check if current user is the host by comparing usernames
        if (hostPlayer && hostPlayer.name === this.currentUsername) return true;

        // Check if current user is a friend of the host
        return this.friendIds.some((friend) => friend.username === hostPlayer?.name);
    }

    onJoin(game: Game) {
        const entryFee = game.settings?.entryFee ?? 0;

        if (entryFee > 0) {
            this.authService.getUserInfo().then((userInfo) => {
                const userMoney = userInfo.user.virtualMoney ?? 0;
                if (userMoney < entryFee) {
                    this.errorModal.open("Vous n'avez pas assez de monnaie virtuelle pour rejoindre cette partie");
                    return;
                }
                this.proceedToJoinGame(game);
            });
        } else {
            this.proceedToJoinGame(game);
        }
    }

    private proceedToJoinGame(game: Game) {
        const existingPlayer = game.players.find((plyr) => plyr.name === this.currentUsername);
        if (existingPlayer) {
            const joinGameData: JoinGameData = { player: existingPlayer, gameId: game.id! };
            this.socketService.sendMessage(GameCreationEvents.ResumeGame, joinGameData);
        } else {
            this.socketService.sendMessage(GameCreationEvents.AccessGame, game.id);
        }
    }

    onResume(game: Game) {
        const existingPlayer = game.players.find((plyr) => plyr.name === this.currentUsername);
        if (existingPlayer) {
            const joinGameData: JoinGameData = { player: existingPlayer, gameId: game.id! };
            this.socketService.sendMessage(GameCreationEvents.ResumeGame, joinGameData);
        }
    }

    onObserve(game: Game) {
        const existingPlayer = game.players.find((plyr) => plyr.name === this.currentUsername);
        if (existingPlayer) {
            const joinGameData: JoinGameData = { player: existingPlayer, gameId: game.id! };
            this.socketService.sendMessage(GameCreationEvents.ObserveGame, joinGameData);
        } else {
            const minimalObserver = this.createMinimalObserverPlayer();
            const joinGameData: JoinGameData = { player: minimalObserver, gameId: game.id! };
            this.socketService.sendMessage(GameCreationEvents.ObserveGame, joinGameData);
        }
    }

    private createMinimalObserverPlayer(): Player {
        const playerSpecs: Specs = {
            life: DEFAULT_HP,
            speed: DEFAULT_SPEED,
            attack: DEFAULT_ATTACK,
            defense: DEFAULT_DEFENSE,
            attackBonus: Bonus.D4,
            defenseBonus: Bonus.D4,
            movePoints: DEFAULT_SPEED,
            evasions: DEFAULT_EVASIONS,
            actions: DEFAULT_ACTIONS,
            nVictories: 0,
            nDefeats: 0,
            nCombats: 0,
            nEvasions: 0,
            nLifeTaken: 0,
            nLifeLost: 0,
            nItemsUsed: 0,
        };

        return {
            name: this.currentUsername,
            socketId: this.socketService.socket.id || '',
            level: 1,
            isActive: false,
            isEliminated: false,
            isObserver: true,
            avatar: Avatar.Avatar1,
            specs: playerSpecs,
            inventory: [],
            position: { x: 0, y: 0 },
            initialPosition: { x: 0, y: 0 },
            turn: 0,
            visitedTiles: [],
            profile: ProfileType.NORMAL,
        };
    }

    configureJoinGameSocketFeatures(): void {
        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameAccessed).subscribe(async (gameId) => {
                this.audioService.stopMusic();
                this.router.navigate([`join-game/${gameId}/create-character`]);
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameResumed).subscribe(async (game) => {
                const existingPlayer = game.players.find((plyr) => plyr.name === this.currentUsername);
                if (existingPlayer) {
                    const joinGameData: JoinGameData = { player: existingPlayer, gameId: game.id! };
                    this.socketService.sendMessage(GameCreationEvents.JoinGame, joinGameData);
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameNotFound).subscribe((reason) => {
                if (reason) {
                    this.errorMessage = reason;
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameLocked).subscribe((reason) => {
                if (reason) {
                    this.errorMessage = reason;
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService
                .listen<{ updatedPlayer: Player; updatedGame: Game }>(GameCreationEvents.YouJoined)
                .subscribe(({ updatedPlayer, updatedGame }) => {
                    if (updatedGame) {
                        this.playerService.setPlayer(updatedPlayer);
                        this.gameService.setGame(updatedGame);
                        this.audioService.stopMusic();
                        this.router.navigate([`/game/${updatedGame.id}/${updatedGame.name}`], {
                            state: { player: this.playerService.player, gameId: updatedGame.id },
                        });
                    }
                }),
        );

        this.socketSubscription.add(
            this.socketService.listen<{ friends: Friend[] }>(FriendsEvents.FriendListUpdated).subscribe((update) => {
                this.friendIds = update.friends;
            }),
        );
    }

    navigateToMain(): void {
        this.router.navigate(['/main-menu']);
    }

    ngOnDestroy(): void {
        if (this.socketSubscription) {
            this.socketSubscription.unsubscribe();
        }

        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }
}
