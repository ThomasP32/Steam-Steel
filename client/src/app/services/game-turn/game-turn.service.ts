import { Injectable } from '@angular/core';
import { AudioService } from '@app/services/audio/audio.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { GameService } from '@app/services/game/game.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { TIME_LIMIT_DELAY } from '@common/constants';
import { MovesMap } from '@common/directions';
import { CombatEvents, CombatFinishedByEvasionData, CombatFinishedData } from '@common/events/combat.events';
import { GameManagerEvents } from '@common/events/game-manager.events';
import { GameTurnEvents } from '@common/events/game-turn.events';
import { ItemsEvents } from '@common/events/items.events';
import { Game, GameEndReason, Player } from '@common/game';
import { Coordinate, DoorTile, ItemCategory, Tile } from '@common/map.types';
import { BehaviorSubject, Subscription } from 'rxjs';

@Injectable({
    providedIn: 'root',
})
export class GameTurnService {
    socketSubscription: Subscription = new Subscription();
    moves: MovesMap = new Map();

    private readonly playerTurn = new BehaviorSubject<string>('');
    public playerTurn$ = this.playerTurn.asObservable();

    private readonly youFell = new BehaviorSubject<boolean>(false);
    public youFell$ = this.youFell.asObservable();

    private readonly playerWon = new BehaviorSubject<boolean>(false);
    public playerWon$ = this.playerWon.asObservable();

    private readonly moneyReward = new BehaviorSubject<number>(0);
    public moneyReward$ = this.moneyReward.asObservable();

    private readonly possibleOpponents = new BehaviorSubject<Player[]>([]);
    public possibleOpponents$ = this.possibleOpponents.asObservable();

    private readonly possibleDoors = new BehaviorSubject<DoorTile[]>([]);
    public possibleDoors$ = this.possibleDoors.asObservable();

    private readonly possibleWalls = new BehaviorSubject<Tile[]>([]);
    public possibleWalls$ = this.possibleWalls.asObservable();

    private readonly gameEndReason = new BehaviorSubject<GameEndReason | null>(null);
    public gameEndReason$ = this.gameEndReason.asObservable();

    isMoving = false;

    possibleActions = { combat: false, door: false, wall: false };

    constructor(
        private readonly gameService: GameService,
        private readonly playerService: PlayerService,
        private readonly socketService: SocketService,
        private readonly audioService: AudioService,
    ) {
        this.gameService = gameService;
        this.playerService = playerService;
        this.socketService = socketService;
        this.audioService = audioService;
    }

    get player(): Player {
        return this.playerService.player;
    }

    get game(): Game {
        return this.gameService.game;
    }

    resumeTurn(): void {
        if (this.playerTurn.getValue() === this.player.name) {
            this.possibleOpponents.next([]);
            this.possibleDoors.next([]);
            this.possibleActions.combat = true;
            this.possibleActions.door = true;

            if (this.player.specs.actions !== 0) {
                if (this.player.inventory.includes(ItemCategory.WallBreaker)) {
                    this.possibleActions.wall = true;
                    this.getWalls();
                }
                this.getCombats();
                this.getDoors();
            } else {
                this.getMoves();
            }
            this.gameService.setGame(this.game);
        }
    }

    endTurn(): void {
        if (!this.youFell.getValue()) {
            this.clearMoves();
            this.socketService.sendMessage(GameTurnEvents.EndTurn, this.game.id);
        }
    }

    endTurnBecauseFell(): void {
        this.youFell.next(true);
        setTimeout(() => {
            this.youFell.next(false);
            this.clearMoves();
            this.endTurn();
        }, TIME_LIMIT_DELAY);
    }

    listenForTurn() {
        this.socketSubscription.add(
            this.socketService.listen<Player>(GameTurnEvents.YourTurn).subscribe((yourPlayer) => {
                this.clearMoves();
                this.playerService.player = yourPlayer;
                this.playerTurn.next(yourPlayer.name);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<string>(GameTurnEvents.PlayerTurn).subscribe((playerName) => {
                this.clearMoves();
                this.youFell.next(false);
                this.playerTurn.next(playerName);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen(GameTurnEvents.StartTurn).subscribe(() => {
                if (this.playerTurn.getValue() === this.player.name) {
                    this.possibleActions.combat = true;
                    this.possibleActions.door = true;
                    if (this.player.inventory.includes(ItemCategory.WallBreaker)) {
                        this.possibleActions.wall = true;
                    }
                    this.getCombats();
                }
            }),
        );
    }

    getCombats(): void {
        this.socketService.sendMessage(CombatEvents.GetCombats, this.game.id);
    }

    getDoors(): void {
        this.socketService.sendMessage(GameManagerEvents.GetAdjacentDoors, this.game.id);
    }

    getWalls(): void {
        this.socketService.sendMessage(GameManagerEvents.GetAdjacentWalls, this.game.id);
    }
    getMoves(): void {
        this.socketService.sendMessage(GameManagerEvents.GetMovements, this.game.id);
    }

    clearMoves(): void {
        this.moves = new Map();
    }

    movePlayer(position: Coordinate) {
        this.socketService.sendMessage(GameManagerEvents.MoveToPosition, {
            playerTurn: this.player.turn,
            gameId: this.game.id,
            destination: position,
        });
    }

    listenMoves(): void {
        this.socketSubscription.add(
            this.socketService
                .listen<[string, { path: Coordinate[]; weight: number }][]>(GameManagerEvents.PlayerPossibleMoves)
                .subscribe((paths) => {
                    this.moves = new Map();
                    this.moves = new Map(paths);
                    if (
                        this.moves.size === 1 &&
                        (this.playerService.player.specs.actions === 0 ||
                            (!this.possibleActions.combat && !this.possibleActions.door && !this.possibleActions.wall))
                    ) {
                        this.endTurn();
                    }
                }),
        );
    }

    toggleDoor(door: DoorTile) {
        if (this.possibleActions.door) {
            this.socketService.sendMessage(ItemsEvents.ToggleDoor, { gameId: this.game.id, door });
            this.possibleActions.door = false;
        }
    }

    breakWall(wall: Tile) {
        if (this.possibleActions.wall) {
            this.socketService.sendMessage(ItemsEvents.BreakWall, { gameId: this.game.id, wall });
            this.possibleActions.wall = false;
        }
    }

    listenForPlayerMove(): void {
        this.socketSubscription.add(
            this.socketService.listen<{ game: Game; player: Player }>(GameManagerEvents.PositionToUpdate).subscribe(async (data) => {
                const playerPosition = data.player.position;
                if (playerPosition) {
                    const tile = data.game.tiles.find((t) => t.coordinate.x === playerPosition.x && t.coordinate.y === playerPosition.y);

                    const randomStep = Math.floor(Math.random() * 4) + 1;
                    const stepNumber = randomStep.toString().padStart(3, '0');

                    if (tile) {
                        if (tile.category === 'water') {
                            this.audioService.playSoundEffect(`SFX_Footsteps_DeepWater_${stepNumber}.mp3`, 0.4);
                        } else if (tile.category === 'ice') {
                            this.audioService.playSoundEffect(`SFX_Footsteps_Ice_${stepNumber}.mp3`, 0.4);
                        } else if (tile.category === 'floor') {
                            this.audioService.playSoundEffect(`SFX_Footsteps_Concrete_${stepNumber}.mp3`, 0.4);
                        }
                    } else {
                        this.audioService.playSoundEffect(`SFX_Footsteps_Concrete_${stepNumber}.mp3`, 0.4);
                    }
                }

                if (data.player.socketId === this.player.socketId) {
                    this.playerService.setPlayer(data.player);
                }
                this.gameService.setGame(data.game);
                this.resumeTurn();
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen(GameManagerEvents.YouFinishedMoving).subscribe(() => {
                this.clearMoves();
                this.resumeTurn();
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen(GameManagerEvents.YouFell).subscribe(() => {
                this.clearMoves();
                this.endTurnBecauseFell();
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameManagerEvents.MoveVirtualPlayer).subscribe((game) => {
                this.gameService.setGame(game);
            }),
        );
    }

    listenForCombatStarted(): void {
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.YouStartedCombat).subscribe((player) => {
                if (player.socketId === this.player.socketId) {
                    this.playerService.setPlayer(player);
                }
            }),
        );
    }

    listenForPossibleActions(): void {
        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameManagerEvents.YourCombats).subscribe((possibleOpponents) => {
                if (possibleOpponents.length === 0) {
                    this.possibleActions.combat = false;
                }
                this.possibleOpponents.next(possibleOpponents);
                this.getDoors();
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<DoorTile[]>(GameManagerEvents.YourDoors).subscribe((possibleDoors) => {
                if (possibleDoors.length === 0) {
                    this.possibleActions.door = false;
                }
                this.possibleDoors.next(possibleDoors);
                this.getMoves();
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<Tile[]>(GameManagerEvents.YourWalls).subscribe((possibleWalls) => {
                if (possibleWalls.length === 0) {
                    this.possibleActions.wall = false;
                }
                this.possibleWalls.next(possibleWalls);
                this.getMoves();
            }),
        );
    }

    listenForWallBreaking(): void {
        this.socketSubscription.add(
            this.socketService.listen<{ game: Game; player: Player }>(ItemsEvents.WallBroken).subscribe((data) => {
                if (data.player && data.player.socketId === this.player.socketId) {
                    this.playerService.setPlayer(data.player);
                    this.resumeTurn();
                }
                this.gameService.setGame(data.game);
            }),
        );
    }

    listenForDoorUpdates(): void {
        this.socketSubscription.add(
            this.socketService.listen<{ game: Game; player: Player }>(ItemsEvents.DoorToggled).subscribe((data) => {
                const doorsManipulated = data.game.nDoorsManipulated;
                if (doorsManipulated.length > 0) {
                    const lastDoorCoord = doorsManipulated.slice(-1)[0];
                    const toggledDoor = data.game.doorTiles.find(
                        (door) => door.coordinate.x === lastDoorCoord.x && door.coordinate.y === lastDoorCoord.y,
                    );

                    if (toggledDoor) {
                        const soundFile = toggledDoor.isOpened ? 'SFX_Door _Open.mp3' : 'SFX_Door _Close.mp3';
                        this.audioService.playSoundEffect(soundFile, 0.5);
                    }
                }

                if (data.player && data.player.socketId === this.player.socketId) {
                    this.playerService.setPlayer(data.player);
                    this.resumeTurn();
                }
                this.gameService.setGame(data.game);
            }),
        );
    }

    listenForCombatConclusion(): void {
        this.socketSubscription.add(
            this.socketService.listen<CombatFinishedByEvasionData>(CombatEvents.CombatFinishedByEvasion).subscribe((data) => {
                if (data.evadingPlayer.socketId === this.player.socketId) {
                    this.playerService.setPlayer(data.evadingPlayer);
                    if (data.updatedGame.currentTurn === this.playerService.player.turn) {
                        this.clearMoves();
                        this.resumeTurn();
                    }
                } else {
                    this.playerService.setPlayer(data.updatedGame.players.filter((player) => player.socketId === this.player.socketId)[0]);
                }
                this.gameService.setGame(data.updatedGame);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<CombatFinishedData>(CombatEvents.CombatFinished).subscribe((data) => {
                const me = data.updatedGame.players.find((player) => player.socketId === this.playerService.player.socketId);
                if (me) {
                    this.playerService.setPlayer(me);
                }
                this.gameService.setGame(data.updatedGame);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen(CombatEvents.ResumeTurnAfterCombatWin).subscribe(() => {
                this.clearMoves();
                this.resumeTurn();
            }),
        );
    }

    listenForFlagHolder(): void {
        this.socketSubscription.add(
            this.socketService.listen<Game>(GameManagerEvents.FlagPickup).subscribe((game) => {
                this.gameService.setGame(game);
            }),
        );
    }

 listenForEndOfGame() {
        let gameFinishedHandled = false;
        let playerWonHandled = false;

        this.socketSubscription.add(
            this.socketService
                .listen<{ updatedGame: Game; moneyRewards?: { [key: string]: number }; reason?: GameEndReason }>(CombatEvents.GameFinished)
                .subscribe((data) => {
                    if (gameFinishedHandled) return;
                    gameFinishedHandled = true;
                    this.gameService.setGame(data.updatedGame);
                    const updatedPlayer = data.updatedGame.players.find((p) => p.socketId === this.playerService.player.socketId);
                    if (updatedPlayer) {
                        this.playerService.setPlayer(updatedPlayer);
                    }

                    const currentSocketId = this.playerService.player.socketId;
                    const reward = data.moneyRewards?.[currentSocketId] || 0;
                    this.moneyReward.next(reward);

                    if (data.reason) {
                        this.gameEndReason.next(data.reason);
                    }

                    if (!playerWonHandled) {
                        playerWonHandled = true;
                        this.playerWon.next(true);
                    }
                }),
        );

        this.socketSubscription.add(
            this.socketService.listen<{ winner: Player; reason: GameEndReason }>(CombatEvents.GameFinishedPlayerWon).subscribe((data) => {
                if (playerWonHandled) return;
                playerWonHandled = true;
                if (data.reason) {
                    this.gameEndReason.next(data.reason);
                }
                this.playerWon.next(true);
            }),
        );

        this.playerWon.next(false);
    }
}
