import { CommonModule } from '@angular/common';
import { Component, EventEmitter, HostListener, Input, OnChanges, OnDestroy, OnInit, Output } from '@angular/core';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { GameDataService } from '@app/services/game-data/game-data.service';
import { GameInfosService } from '@app/services/game-infos/game-infos.service';
import { ImageService } from '@app/services/image/image.service';
import { ALTERNATIVE_COORDINATES, RIGHT_CLICK, TOOLTIP_DIRECTION_CHANGE } from '@common/constants';
import { MovesMap } from '@common/directions';
import { GameManagerEvents } from '@common/events/game-manager.events';
import { Avatar, Game, Player } from '@common/game';
import { Cell } from '@common/map-cell';
import { Coordinate, ItemCategory, Mode, TileCategory } from '@common/map.types';
import { Subscription } from 'rxjs';

@Component({
    selector: 'app-game-map',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './game-map.component.html',
    styleUrl: './game-map.component.scss',
})
export class GameMapComponent implements OnInit, OnChanges, OnDestroy {
    @Input() loadedMap: Game;
    @Input() player: Player;
    @Input() moves: MovesMap;
    @Output() tileClicked = new EventEmitter<Coordinate>();
    @Input() isYourTurn: boolean;
    movePreview: Coordinate[] = [];
    map: Cell[][];
    tileDescription: string = '';
    explanationIsVisible: boolean = false;
    tooltipX: number = 0;
    tooltipY: number = 0;
    playerStartTile: Coordinate | null = null;
    private playerStartTileSubscription: Subscription;

    constructor(
        private readonly imageService: ImageService,
        private readonly gameInfosService: GameInfosService,
        private readonly gameDataService: GameDataService,
        private readonly socketService: SocketService,
    ) {
        this.gameInfosService = gameInfosService;
        this.gameDataService = gameDataService;
        this.imageService = imageService;
        this.socketService = socketService;
    }

    onTileClick(position: Coordinate) {
        const key = `${position.x},${position.y}`;
        if (this.moves.has(key)) {
            this.tileClicked.emit(position);
        }
    }

    ngOnInit() {
        this.loadMap(this.loadedMap);
        this.setupPlayerStartTileListener();
    }

    ngOnChanges() {
        this.clearPreview();
        this.loadMap(this.loadedMap);
        this.updateSurroundingMap(this.player);

        if (this.loadedMap?.mode === Mode.Ctf && !this.playerStartTileSubscription) {
            this.setupPlayerStartTileListener();
        }
    }

    onTileHover(position: Coordinate) {
        const coordinateKey = `${position.x},${position.y}`;
        const move = this.moves.get(coordinateKey);
        if (move) {
            this.movePreview = move.path;
        } else {
            this.clearPreview();
        }
    }

    clearPreview() {
        this.movePreview = [];
    }

    loadMap(loadedMap: Game) {
        this.createMap(loadedMap.mapSize.x);

        loadedMap.tiles.forEach((tile) => {
            this.map[tile.coordinate.x][tile.coordinate.y].tileType = tile.category;
        });

        loadedMap.doorTiles.forEach((door) => {
            this.map[door.coordinate.x][door.coordinate.y].tileType = TileCategory.Door;
            this.map[door.coordinate.x][door.coordinate.y].door.isDoor = true;
            this.map[door.coordinate.x][door.coordinate.y].door.isOpen = door.isOpened;
        });
        loadedMap.startTiles.forEach((start) => {
            this.map[start.coordinate.x][start.coordinate.y].isStartingPoint = true;
        });

        loadedMap.items.forEach((item) => {
            this.map[item.coordinate.x][item.coordinate.y].item = item.category;
        });

        loadedMap.players.forEach((player) => {
            if (player.isActive && !player.isEliminated) {
                this.map[player.position.x][player.position.y].player = player;
            }
        });
    }

    createMap(mapSize: number) {
        this.map = [];
        for (let i = 0; i < mapSize; i++) {
            const row: Cell[] = [];
            for (let j = 0; j < mapSize; j++) {
                row.push({
                    coordinate: { x: i, y: j },
                    tileType: TileCategory.Floor,
                    door: { isOpen: false, isDoor: false },
                    isHovered: false,
                    isOccupied: false,
                    isStartingPoint: false,
                    alternateCoordinates: { x: i, y: j },
                });
            }
            this.map.push(row);
        }
    }
    getTileImage(tileType: TileCategory, rowIndex: number, colIndex: number): string {
        if (tileType === TileCategory.Door) {
            return this.imageService.getDoorImage(this.map[rowIndex][colIndex].door.isOpen);
        } else return this.imageService.getTileImage(tileType);
    }

    getStartingPointImage(): string {
        return this.imageService.getStartingPointImage();
    }

    getItemImage(item: ItemCategory): string {
        return this.imageService.getItemImage(item);
    }

    getAvatarImage(avatar: Avatar): string {
        return this.imageService.getPixelatedPlayerImage(avatar);
    }

    isMove(rowIndex: number, colIndex: number): boolean {
        const coordinateKey = `${rowIndex},${colIndex}`;
        const move = this.moves.get(coordinateKey);
        return move !== undefined;
    }

    isPreview(rowIndex: number, colIndex: number): boolean {
        return this.movePreview.some((coord) => coord.x === rowIndex && coord.y === colIndex);
    }

    onRightClickTile(event: MouseEvent, position: Coordinate) {
        if (event.button === 2) {
            event.preventDefault();
            this.tileDescription = this.gameInfosService.getTileDescription(position, this.loadedMap);
            this.tooltipX = event.pageX + TOOLTIP_DIRECTION_CHANGE;
            this.tooltipY = event.pageY + TOOLTIP_DIRECTION_CHANGE;
            this.explanationIsVisible = true;
        }
    }

    @HostListener('window:mouseup', ['$event'])
    onRightClickRelease(event: MouseEvent) {
        if (event.button === RIGHT_CLICK) {
            this.explanationIsVisible = false;
            this.tileDescription = '';
        }
    }

    rowByIndex(index: number) {
        return index;
    }

    cellByIndex(index: number) {
        return index;
    }
    getSurroundingMap(player: Player): Cell[][] {
        const range = ALTERNATIVE_COORDINATES;
        const surroundingCells: Cell[][] = [];

        for (let dx = -range; dx <= range; dx++) {
            for (let dy = -range; dy <= range; dy++) {
                const x = player.position.x + dx;
                const y = player.position.y + dy;
                if (!surroundingCells[dx + range]) surroundingCells[dx + range] = [];

                if (x >= 0 && x < this.map.length && y >= 0 && y < this.map[0].length) {
                    const originalCell = this.map[x][y];
                    const alternateCoordinates = { x: dx + range, y: dy + range };

                    const door =
                        originalCell.tileType === TileCategory.Door
                            ? { isDoor: true, isOpen: originalCell.door?.isOpen || false }
                            : { isDoor: false, isOpen: false };

                    const cell = {
                        ...originalCell,
                        door,
                        alternateCoordinates,
                    };

                    surroundingCells[dx + range][dy + range] = cell;
                } else {
                    surroundingCells[dx + range][dy + range] = {
                        tileType: TileCategory.Floor,
                        door: { isDoor: false, isOpen: false },
                        isHovered: false,
                        isOccupied: false,
                        isStartingPoint: false,
                        coordinate: { x, y },
                        alternateCoordinates: { x: dx + range, y: dy + range },
                    } as Cell;
                }
            }
        }

        return surroundingCells;
    }
    ngOnDestroy() {
        if (this.playerStartTileSubscription) {
            this.playerStartTileSubscription.unsubscribe();
        }
    }

    private setupPlayerStartTileListener() {
        this.playerStartTileSubscription = this.socketService
            .listen<Coordinate | null>(GameManagerEvents.PlayerStartTile)
            .subscribe((coordinate: Coordinate | null) => {
                if (this.loadedMap?.mode === Mode.Ctf) {
                    this.playerStartTile = coordinate;
                }
            });
    }

    isPlayerStartTile(rowIndex: number, colIndex: number): boolean {
        const isStartTile = this.playerStartTile !== null && this.playerStartTile.x === rowIndex && this.playerStartTile.y === colIndex;
        return isStartTile;
    }

    updateSurroundingMap(player: Player) {
        const surroundingMap = this.getSurroundingMap(player);
        this.gameDataService.setSurroundingMap(surroundingMap);
    }
}
