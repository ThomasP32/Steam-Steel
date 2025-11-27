import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { GameOptionsModalComponent } from '@app/components/game-options-modal/game-options-modal.component';
import { AudioService } from '@app/services/audio/audio.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { AdminEvents } from '@common/events/admin.events';
import { Map, Mode } from '@common/map.types';
import { firstValueFrom, Subject, takeUntil } from 'rxjs';
import { VirtualMoneyComponent } from '@app/components/virtual-money/virtual-money.component';

@Component({
    selector: 'app-game-choice-page',
    standalone: true,
    templateUrl: './game-choice-page.component.html',
    styleUrls: ['./game-choice-page.component.scss'],
    imports: [CommonModule, ChatroomComponent, GameOptionsModalComponent, VirtualMoneyComponent],
})
export class GameChoicePageComponent implements OnInit, OnDestroy {
    map: Map;
    maps: Map[] = [];
    selectedMap: string | undefined = undefined;
    showErrorMessage: { userError: boolean; gameChoiceError: boolean } = {
        userError: false,
        gameChoiceError: false,
    };
    isChatVisible: boolean = false;
    showGameOptionsModal: boolean = false;
    gameSettings: { isFastElimination: boolean; isDropInOut: boolean; isFriendsOnly: boolean; entryFee: number } = {
        isFastElimination: false,
        isDropInOut: false,
        isFriendsOnly: false,
        entryFee: 0,
    };

    isFilterOpen: boolean = false;
    sortBy: 'name' | 'players' | 'mode' | null = null;
    sortOrder: 'asc' | 'desc' = 'asc';
    sortedMaps: Map[];

    private readonly router: Router = inject(Router);
    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly communicationMapService: CommunicationMapService,
        private readonly mapConversionService: MapConversionService,
        private readonly socketService: SocketService,
        private readonly audioService: AudioService,
    ) {
        this.communicationMapService = communicationMapService;
        this.mapConversionService = mapConversionService;
        this.socketService = socketService;
        this.audioService = audioService;
    }

    async ngOnInit(): Promise<void> {
        await this.loadMaps();

        // Écouter les mises à jour des maps via WebSocket
        this.socketService
            .listen<void>(AdminEvents.MapListUpdated)
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe(() => {
                this.loadMaps();
            });
    }

    private async loadMaps(): Promise<void> {
        const token = localStorage.getItem('authToken');
        if (token) {
            this.maps = await firstValueFrom(this.communicationMapService.basicGet<Map[]>(`map/user/visible?token=${token}`));
        } else {
            this.maps = await firstValueFrom(this.communicationMapService.basicGet<Map[]>('map'));
        }
        this.sortedMaps = this.maps;
    }

    selectMap(mapName: string) {
        this.selectedMap = mapName;
        this.showGameOptionsModal = true;
    }

    getMapPlayers(mapSize: number): string {
        return this.mapConversionService.getPlayerCountMessage(mapSize);
    }

    toggleSort(sortOption: 'name' | 'players' | 'mode') {
        if (this.sortBy === sortOption) {
            this.sortBy = null;
            this.sortOrder = 'asc';
            this.sortedMaps = [...this.maps];
        } else {
            this.sortBy = sortOption;
            this.applySort();
        }
    }

    toggleOrder() {
        this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
        if (this.sortBy) this.applySort();
    }

    applySort() {
        const direction = this.sortOrder === 'asc' ? 1 : -1;
        const modeWeight = (mode: string) => (mode === Mode.Classic ? 1 : mode === Mode.Ctf ? 2 : 99);

        this.sortedMaps.sort((a, b) => {
            let va: any, vb: any;
            switch (this.sortBy) {
                case 'name':
                    va = a.name.toLowerCase();
                    vb = b.name.toLowerCase();
                    break;
                case 'players':
                    va = this.getMapPlayers(a.mapSize.x);
                    vb = this.getMapPlayers(b.mapSize.x);
                    break;
                case 'mode':
                    va = modeWeight(a.mode);
                    vb = modeWeight(b.mode);
                    break;
                default:
                    return 0;
            }
            if (va < vb) return -1 * direction;
            if (va > vb) return 1 * direction;
            return 0;
        });
    }

    onReturn() {
        this.router.navigate(['/']);
    }

    closeGameOptionsModal(): void {
        this.showGameOptionsModal = false;
        this.selectedMap = undefined;
    }

    onGameOptionsNext(options: { isFastElimination: boolean; isDropInOut: boolean; isFriendsOnly: boolean; entryFee: number }): void {
        this.gameSettings = options;
        this.showGameOptionsModal = false;
        if (this.selectedMap) {
            this.audioService.stopMusic();
            this.router.navigate([`create-game/${this.selectedMap}/create-character`], {
                state: { gameSettings: this.gameSettings },
            });
        }
    }

    changeHeightMap(mapSize: number): string {
        switch (mapSize) {
            case 10:
                return "Petite";
            case 15:
                return "Moyenne";
            case 20:
                return "Grande";
            default:
                return "Bug";
        }
    }

    ngOnDestroy(): void {
        this.unsubscribe$.complete();
    }
}
