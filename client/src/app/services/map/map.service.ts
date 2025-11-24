import { HttpErrorResponse } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '@app/services/auth/auth.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { Cell } from '@common/map-cell';
import { DetailedMap, ItemCategory, Map, MapState, Mode, TileCategory } from '@common/map.types';
import { BehaviorSubject, Subject, firstValueFrom } from 'rxjs';

@Injectable({
    providedIn: 'root',
})
export class MapService {
    map!: Map;

    selectedTile: string;

    resetMapSource = new Subject<void>();
    resetMap$ = this.resetMapSource.asObservable();

    generateMapSource = new Subject<void>();
    generateMap$ = this.generateMapSource.asObservable();

    updateSelectedTileSource = new BehaviorSubject<string>('');
    updateSelectedTile$ = this.updateSelectedTileSource.asObservable();

    removeStartingPointSource = new Subject<boolean>();
    removeStartingPoint$ = this.removeStartingPointSource.asObservable();

    constructor(
        private readonly communicationMapService: CommunicationMapService,
        private readonly router: Router,
        private readonly authService: AuthService,
    ) {
        this.communicationMapService = communicationMapService;
        this.router = router;
        this.authService = authService;
    }

    async getMap(id: string): Promise<void> {
        try {
            // _id, isVisible, lastModified are used to extract the properties from the map returned by basicGet
            // eslint-disable-next-line no-unused-vars
            const { _id, isVisible, lastModified, ...restOfMap } = await firstValueFrom(
                this.communicationMapService.basicGet<DetailedMap>(`admin/${id}`),
            );
            this.map = { ...restOfMap };
        } catch (error) {
            this.router.navigate(['/']);
        }
    }

    createMap(mode: Mode, size: number): void {
        this.map = {
            name: '',
            description: '',
            imagePreview: '',
            mode: mode,
            mapSize: { x: size, y: size },
            startTiles: [],
            items: [],
            doorTiles: [],
            tiles: [],
            state: MapState.Public,
            creator: '',
        };
    }

    generateMap() {
        this.generateMapSource.next();
    }

    generateMapFromEdition(newMap: Cell[][]): void {
        this.map.doorTiles = [];
        this.map.tiles = [];
        this.map.items = [];
        this.map.startTiles = [];

        for (let rowIndex = 0; rowIndex < newMap.length; rowIndex++) {
            for (let colIndex = 0; colIndex < newMap[rowIndex].length; colIndex++) {
                const cell = newMap[rowIndex][colIndex];
                const coordinate = { x: rowIndex, y: colIndex };

                if (cell && cell.tileType) {
                    if (cell.door?.isDoor) {
                        this.map.doorTiles.push({
                            coordinate,
                            isOpened: cell.door.isOpen,
                        });
                    } else if (['water', 'ice', 'wall'].includes(cell.tileType)) {
                        this.map.tiles.push({
                            coordinate,
                            category: cell.tileType as TileCategory,
                        });
                    }

                    if (cell.item) {
                        this.map.items.push({
                            coordinate,
                            category: cell.item as ItemCategory,
                        });
                    }

                    if (cell.isStartingPoint) {
                        this.map.startTiles.push({
                            coordinate,
                        });
                    }
                }
            }
        }
    }

    resetMap() {
        this.resetMapSource.next();
    }

    updateSelectedTile(value: string) {
        this.updateSelectedTileSource.next(value);
    }

    removeStartingPoint(isStartingPoint: boolean) {
        this.removeStartingPointSource.next(isStartingPoint);
    }

    async saveNewMap(): Promise<string> {
        try {
            const userInfo = await this.authService.getUserInfo();

            this.map.creator = userInfo.user._id;

            await firstValueFrom(this.communicationMapService.basicPost<any>('admin/creation', this.map));
        } catch (error) {
            return this.handleHttpError(error);
        }
        return 'Votre jeu a été sauvegardé avec succès!';
    }

    async updateMap(mapId: string): Promise<string> {
        try {
            const userInfo = await this.authService.getUserInfo();

            const payload = {
                mapDto: this.map,
                userId: userInfo.user._id,
            };

            await firstValueFrom(this.communicationMapService.basicPut<any>(`admin/edition/${mapId}`, payload));
        } catch (error) {
            return this.handleHttpError(error);
        }
        return 'Votre jeu a été sauvegardé avec succès!';
    }

    async deleteMap(mapId: string): Promise<void> {
        const userInfo = await this.authService.getUserInfo();

        const payload = {
            userId: userInfo.user._id,
        };

        await firstValueFrom(this.communicationMapService.basicDeleteWithBody(`admin/${mapId}`, payload));
    }

    async duplicateMap(mapId: string): Promise<void> {
        const userInfo = await this.authService.getUserInfo();

        const payload = {
            userId: userInfo.user._id,
        };

        await firstValueFrom(this.communicationMapService.basicPost<any>(`admin/duplicate/${mapId}`, payload));
    }

    async toggleMapVisibility(mapId: string): Promise<void> {
        await firstValueFrom(this.communicationMapService.basicPatch<any>(`admin/${mapId}`));
    }

    private handleHttpError(error: any): string {
        if (error instanceof HttpErrorResponse) {
            let errorMessage = 'Erreur inattendue, veuillez réessayer plus tard...';
            if (error.error) {
                try {
                    const errorObj = JSON.parse(error.error);
                    if (typeof errorObj.message === 'string') {
                        errorMessage = errorObj.message;
                    } else {
                        const message: string = errorObj.message.join(' ');
                        errorMessage = message;
                    }
                } catch (e) {
                    return errorMessage;
                }
            }
            return errorMessage;
        } else {
            return 'Erreur inconnue, veuillez réessayer plus tard...';
        }
    }
}
