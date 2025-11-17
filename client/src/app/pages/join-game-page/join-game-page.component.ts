import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { ErrorMessageComponent } from '@app/components/error-message-component/error-message.component';
import { GamePreviewComponent } from '@app/components/game-preview/game-preview.component';
import { JoinGameModalComponent } from '@app/components/join-game-modal/join-game-modal.component';
import { VirtualMoneyComponent } from '@app/components/virtual-money/virtual-money.component';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { FriendsService } from '@app/services/friends/friends.service';
import { GameService } from '@app/services/game/game.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents, JoinGameData } from '@common/events/game-creation.events';
import { Game, Player } from '@common/game';
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
    ) {
        this.router = router;
        this.authService = authService;
        this.socketService = socketService;
        this.playerService = playerService;
        this.gameService = gameService;
        this.friendsService = friendsService;
    }

    async ngOnInit(): Promise<void> {
        try {
            await this.authService.getUserInfo();
        } catch (error) {
            console.error('Erreur lors de la récupération des informations utilisateur:', error);
        }
        await this.loadUserInfo();
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
        this.socketService.sendMessage(GameCreationEvents.GetGames, (gameRooms: Game[]) => {
            this.activeGames = gameRooms.filter((game) => this.canSeeGame(game));
        });
    }

    canSeeGame(game: Game): boolean {
        if (!game.settings.isFriendsOnly) return true;
        const hostId = game.hostSocketId;
        const hostPlayer = game.players.find((plyr) => plyr.socketId === hostId);
        if (hostId === this.currentUserId) return true;
        return this.friendIds.some((friend) => friend.username === hostPlayer?.name);
    }

    onJoin(game: Game) {
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
        if(existingPlayer){
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
            this.router.navigate([`join-game/${game.id}/create-character`], {
                state: { isObserver: true },
            });
        }
    }

    configureJoinGameSocketFeatures(): void {
        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameAccessed).subscribe(async (gameId) => {
                this.router.navigate([`join-game/${gameId}/create-character`]);
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameResumed).subscribe(async (game) => {
                const existingPlayer = game.players.find((plyr) => plyr.name === this.currentUsername);
                if (existingPlayer){
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
        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }
}
