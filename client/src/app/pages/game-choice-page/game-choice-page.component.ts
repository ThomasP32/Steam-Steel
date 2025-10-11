import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { AdminEvents } from '@common/events/admin.events';
import { Map } from '@common/map.types';
import { firstValueFrom, Subject, takeUntil } from 'rxjs';
@Component({
    selector: 'app-game-choice-page',
    standalone: true,
    templateUrl: './game-choice-page.component.html',
    styleUrls: ['./game-choice-page.component.scss'],
    imports: [CommonModule, ChatroomComponent],
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

    private readonly router: Router = inject(Router);
    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly communicationMapService: CommunicationMapService,
        private readonly mapConversionService: MapConversionService,
        private readonly socketService: SocketService,
    ) {
        this.communicationMapService = communicationMapService;
        this.mapConversionService = mapConversionService;
        this.socketService = socketService;
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
        this.maps = await firstValueFrom(this.communicationMapService.basicGet<Map[]>('map'));
    }

    selectMap(mapName: string) {
        this.selectedMap = mapName;
    }

    getMapPlayers(mapSize: number): string {
        return this.mapConversionService.getPlayerCountMessage(mapSize);
    }

    async next() {
        if (this.selectedMap) {
            this.router.navigate([`create-game/${this.selectedMap}/create-character`]);
        } else {
            this.showErrorMessage.userError = true;
        }
    }

    onReturn() {
        this.router.navigate(['/']);
    }

    ngOnDestroy(): void {
        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }
}
