import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ChallengeComponent } from '@app/components/challenge/challenge.component';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { CombatModalComponent } from '@app/components/combat-modal/combat-modal.component';
import { GameMapComponent } from '@app/components/game-map/game-map.component';
import { GamePlayersListComponent } from '@app/components/game-players-list/game-players-list.component';
import { InventoryModalComponent } from '@app/components/inventory-modal/inventory-modal.component';
import { ObservationModeModalComponent } from '@app/components/observation-mode-modal/observation-mode-modal.component';
import { PlayerInfosComponent } from '@app/components/player-infos/player-infos.component';
import { AuthService } from '@app/services/auth/auth.service';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { ChannelService } from '@app/services/channel/channel.service';
import { CharacterService } from '@app/services/character/character.service';
import { CombatService } from '@app/services/combat/combat.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CombatCountdownService } from '@app/services/countdown/combat/combat-countdown.service';
import { CountdownService } from '@app/services/countdown/game/countdown.service';
import { GameTurnService } from '@app/services/game-turn/game-turn.service';
import { GameService } from '@app/services/game/game.service';
import { ImageService } from '@app/services/image/image.service';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { COUNTDOWN_PULSE, MAX_CHAR, TIME_DASH_OFFSET, TIME_LIMIT_DELAY, TIME_PULSE, TIME_REDIRECTION, TURN_DURATION } from '@common/constants';
import { MovesMap } from '@common/directions';
import { CountdownEvents } from '@common/events/countdown.events';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { GameManagerEvents } from '@common/events/game-manager.events';
import { ItemDroppedData, ItemsEvents } from '@common/events/items.events';
import { Game, Player, Specs } from '@common/game';
import { GamePageActiveView } from '@common/game-page';
import { Coordinate, Map } from '@common/map.types';
import { UserStatus } from '@common/user-friends';
import { Subscription } from 'rxjs';
@Component({
    selector: 'app-game-page',
    standalone: true,
    imports: [
        CommonModule,
        GameMapComponent,
        ChatroomComponent,
        GamePlayersListComponent,
        CombatModalComponent,
        PlayerInfosComponent,
        InventoryModalComponent,
        ObservationModeModalComponent,
        ChallengeComponent,
    ],
    templateUrl: './game-page.html',
    styleUrl: './game-page.scss',
})
export class GamePageComponent implements OnInit, OnDestroy {
    private readonly socketSubscription: Subscription = new Subscription();

    isChatVisible: boolean = false;
    GamePageActiveView = GamePageActiveView;
    activeView: GamePageActiveView = GamePageActiveView.Chat;
    activePlayers: Player[];
    opponent: Player;
    combatPlayer: Player;
    possibleOpponents: Player[];
    doorActionAvailable: boolean = false;

    dashArray: string = `${TIME_DASH_OFFSET}`;
    dashOffset: string = `${TIME_DASH_OFFSET}`;

    currentPlayerTurn: string;

    isYourTurn: boolean = false;
    delayFinished: boolean = true;

    isPulsing = false;
    countdown: number | string = TURN_DURATION;
    startTurnCountdown: number = 3;

    showExitModal: boolean = false;
    showKickedModal: boolean = false;
    showEndGameModal: boolean = false;
    showNoActivePlayersModal: boolean = false;
    gameOverMessage: boolean = false;
    isCombatModalOpen: boolean = false;
    isInventoryModalOpen = false;
    isObservationModeModalOpen = false;
    observationModeMessage = '';

    youFell: boolean = false;
    map: Map;
    specs: Specs;
    combatAvailable: boolean = false;
    gameMapComponent: GameMapComponent;

    constructor(
        private readonly router: Router,
        private readonly socketService: SocketService,
        private readonly characterService: CharacterService,
        private readonly playerService: PlayerService,
        private readonly gameService: GameService,
        private readonly gameTurnService: GameTurnService,
        private readonly countDownService: CountdownService,
        private readonly combatCountdownService: CombatCountdownService,
        private readonly combatService: CombatService,
        protected readonly imageService: ImageService,
        protected readonly mapConversionService: MapConversionService,
        private readonly authService: AuthService,
        private readonly channelService: ChannelService,
        private readonly challengeService: ChallengeService,
    ) {
        this.router = router;
        this.socketService = socketService;
        this.characterService = characterService;
        this.playerService = playerService;
        this.gameTurnService = gameTurnService;
        this.countDownService = countDownService;
        this.combatCountdownService = combatCountdownService;
        this.gameService = gameService;
        this.combatService = combatService;
        this.imageService = imageService;
        this.mapConversionService = mapConversionService;
        this.authService = authService;
        this.channelService = channelService;
        this.challengeService = challengeService;
    }

    ngOnInit() {
        if (!this.socketService.isSocketAlive()) {
            this.ngOnDestroy();
            this.leaveGame();
            return;
        }
        this.listenForGameUpdate();

        if (this.player && this.game) {
            this.gameTurnService.listenForTurn();
            this.gameTurnService.listenForPlayerMove();
            this.gameTurnService.listenMoves();
            this.gameTurnService.listenForPossibleActions();
            this.gameTurnService.listenForDoorUpdates();
            this.gameTurnService.listenForWallBreaking();
            this.gameTurnService.listenForCombatConclusion();
            this.gameTurnService.listenForEndOfGame();
            this.combatService.listenCombatStart();
            this.combatService.listenForCombatFinish();
            this.combatService.listenForEvasionInfo();
            this.combatService.listenForObservationMode();

            this.listenForEndOfGame();
            this.listenForOpponent();
            this.listenForCombatPlayer();
            this.listenForStartTurnDelay();
            this.listenForFalling();
            this.listenForCountDown();
            this.listenPlayersLeft();
            this.listenForCurrentPlayerUpdates();
            this.listenForInventoryFull();
            this.listenForCombatModal();
            this.listenForObservationModeModal();
            this.listenForNoActivePlayers();

            this.challengeService.reinitializeListeners();
            this.countDownService.reinitializeListeners();
            this.combatCountdownService.reinitializeListeners();

            this.activePlayers = this.gameService.game.players;

            if (this.playerService.player.socketId === this.game.hostSocketId) {
                this.socketService.sendMessage(GameManagerEvents.StartGame, this.gameService.game.id);
            }
        }
    }

    get player(): Player {
        return this.playerService.player;
    }

    get game(): Game {
        return this.gameService.game;
    }

    get moves(): MovesMap {
        return this.gameTurnService.moves;
    }

    get winnerName(): string {
        if (!this.game || !this.game.players) return 'Un joueur';
        const winner = this.game.players.find((p) => p.isGameWinner);
        return winner?.name || 'Un joueur';
    }

    toggleView(view: GamePageActiveView): void {
        this.activeView = view;
    }

    leaveGame(): void {
        this.showExitModal = false;
        this.socketService.sendMessage(GameCreationEvents.LeaveGame, this.game.id);
        this.playerService.resetPlayer();
        this.channelService.removePartyChannel(this.game.id);
        this.challengeService.resetChallenge();
        this.socketService.sendMessage(FriendsEvents.UpdateUserStatus, { status: UserStatus.Online });

        setTimeout(() => {
            this.characterService.resetCharacterAvailability();
            // Socket stays connected - only leaving the game room
            this.router.navigate(['/main-menu'], { state: {} });
        }, 100);
    }

    areModalsOpen(): boolean {
        return this.showExitModal || this.showKickedModal || this.isCombatModalOpen || this.isObservationModeModalOpen || this.showNoActivePlayersModal;
    }

    navigateToEndOfGame(): void {
        this.router.navigate(['/end-game']);
    }

    openExitConfirmationModal(): void {
        this.showExitModal = true;
    }

    closeExitModal(): void {
        this.showExitModal = false;
    }

    onTileClickToMove(position: Coordinate) {
        this.gameTurnService.movePlayer(position);
    }

    triggerPulse(): void {
        this.isPulsing = true;
        setTimeout(() => (this.isPulsing = false), TIME_PULSE);
    }

    protected listenForCurrentPlayerUpdates() {
        this.gameTurnService.playerTurn$.subscribe((playerName) => {
            this.currentPlayerTurn = playerName;
            this.countdown = TURN_DURATION;
            this.isYourTurn = false;
            if (playerName === this.player.name) {
                this.isYourTurn = true;
            }
        });
    }

    private listenForFalling() {
        this.gameTurnService.youFell$.subscribe((youFell) => {
            this.possibleOpponents = [];
            this.youFell = youFell;
        });
    }

    listenForInventoryFull() {
        this.socketSubscription.add(
            this.socketService.listen(ItemsEvents.InventoryFull).subscribe(() => {
                this.isInventoryModalOpen = true;
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<ItemDroppedData>(ItemsEvents.ItemDropped).subscribe((data) => {
                this.isInventoryModalOpen = false;
                if (data.updatedPlayer && data.updatedPlayer.socketId === this.player.socketId) {
                    this.playerService.setPlayer(data.updatedPlayer);
                    this.gameTurnService.resumeTurn();
                }
                this.gameService.setGame(data.updatedGame);
            }),
        );
    }

    listenForCombatModal() {
        this.combatService.isCombatModalOpen$.subscribe((isCombatModalOpen) => {
            this.isCombatModalOpen = isCombatModalOpen;
            if (!isCombatModalOpen) {
                this.gameTurnService.clearMoves();
            }
        });
    }

    listenForObservationModeModal() {
        this.combatService.showObservationModeModal$.subscribe((showModal) => {
            this.isObservationModeModalOpen = showModal;
        });

        this.combatService.observationModeMessage$.subscribe((message) => {
            this.observationModeMessage = message;
        });
    }

    closeObservationModeModal(): void {
        this.combatService.closeObservationModeModal();
    }

    private listenForNoActivePlayers(): void {
        this.socketSubscription.add(
            this.socketService.listen(GameCreationEvents.GameEndedNoActivePlayers).subscribe(() => {
                this.showNoActivePlayersModal = true;
                setTimeout(() => {
                    this.leaveGame();
                }, TIME_REDIRECTION);
            }),
        );
    }

    private listenForCountDown() {
        this.countDownService.countdown$.subscribe((time) => {
            this.countdown = time;
            const timeLeft = typeof time === 'string' ? parseInt(time, MAX_CHAR) : time;
            const progress = (timeLeft / TURN_DURATION) * TIME_DASH_OFFSET;
            this.dashOffset = `${TIME_DASH_OFFSET - progress}`;
            if (timeLeft < COUNTDOWN_PULSE) {
                this.triggerPulse();
            }
        });
    }

    private listenForEndOfGame() {
        this.gameTurnService.playerWon$.subscribe((isGameOver) => {
            this.showExitModal = false;
            this.showEndGameModal = isGameOver;
            if (isGameOver) {
                const mode = this.game.mode;
                const duration = this.game.duration ?? 0;
                this.authService.updateStats({ mode, isWin: !!this.player.isGameWinner, duration });
                setTimeout(() => {
                    this.navigateToEndOfGame();
                }, TIME_REDIRECTION);
            }
        });
    }

    private listenForOpponent() {
        this.combatService.opponent$.subscribe((opponent) => {
            this.opponent = opponent;
        });
    }

    private listenForCombatPlayer() {
        this.combatService.combatPlayer$.subscribe((combatPlayer) => {
            this.combatPlayer = combatPlayer;
        });
    }

    listenPlayersLeft() {
        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameCreationEvents.PlayerLeft).subscribe((players: Player[]) => {
                this.gameService.game.players = players;
                this.game.players = players;
                this.activePlayers = players.filter((player) => player.isActive);
                const allVirtual = this.activePlayers.length > 0 && this.activePlayers.every((player) => player.socketId.includes('virtualPlayer'));
                if (this.activePlayers.length <= 1 || allVirtual) {
                    this.showExitModal = false;
                    this.showKickedModal = true;
                    setTimeout(() => {
                        this.leaveGame();
                    }, TIME_LIMIT_DELAY);
                }
            }),
        );
    }

    listenForStartTurnDelay() {
        this.socketSubscription.add(
            this.socketService.listen<number>(CountdownEvents.Delay).subscribe((delay) => {
                this.startTurnCountdown = delay;
                if (delay > 0) {
                    this.delayFinished = false;
                }
                
                if (delay === 0) {
                    this.startTurnCountdown = 3;
                    this.delayFinished = true;
                }
            }),
        );
    }

    listenForGameUpdate(): void {
        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameUpdated).subscribe((game) => {
                this.gameService.setGame(game);
                const me = game.players.find(p => p.socketId === this.playerService.player?.socketId);
                if(me) this.playerService.setPlayer(me);
                this.activePlayers = game.players.filter((p) => p.isActive);
   
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameCreationEvents.CurrentPlayers).subscribe((players: Player[]) => {
                if (players && players.length > 0) {
                    this.game.players = players;
                }
            }),
        );
    }

    ngOnDestroy(): void {
        this.socketSubscription.unsubscribe();
    }

    onShowExitModalChange(newValue: boolean) {
        this.showExitModal = newValue;
    }
}
