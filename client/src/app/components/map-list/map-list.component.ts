import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, OnDestroy, OnInit, Output } from '@angular/core';
import { Router } from '@angular/router';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { MapService } from '@app/services/map/map.service';
import { DetailedMap, MapState } from '@common/map.types';
import { Subject, firstValueFrom } from 'rxjs';

@Component({
    selector: 'app-map-list',
    standalone: true,
    templateUrl: './map-list.component.html',
    styleUrls: ['./map-list.component.scss'],
    imports: [CommonModule],
})
export class MapListComponent implements OnInit, OnDestroy {
    @Input() maps: DetailedMap[] = [];
    @Input() currentUsername: string = '';
    @Output() mapDuplicated = new EventEmitter<void>();

    currentMapId: string | null = null;
    mapCreators = new Map<string, string>();
    showDeleteModal = false;
    private readonly unsubscribe$ = new Subject<void>();
    publicSate = MapState.Public;

    constructor(
        private readonly router: Router,
        private readonly mapService: MapService,
        private readonly communicationMapService: CommunicationMapService,
    ) {
        this.router = router;
        this.mapService = mapService;
        this.communicationMapService = communicationMapService;
    }

    async ngOnInit(): Promise<void> {
        for (const map of this.maps) {
            this.getMapCreator(map).then((username) => {
                this.mapCreators.set(map._id.toString(), username);
            });
        }
    }

    async getMapCreator(map: DetailedMap): Promise<string> {
        const username = await firstValueFrom(this.communicationMapService.basicGet<string>(`admin/username/${map.creator}`));
        return username;
    }

    onEditMap(map: DetailedMap): void {
        this.router.navigate([`/edition/${map._id}`]);
    }

    onDeleteMap(map: DetailedMap): void {
        this.currentMapId = map._id.toString();
        this.showDeleteModal = true;
    }

    async onDuplicateMap(map: DetailedMap): Promise<void> {
        try {
            await this.mapService.duplicateMap(map._id.toString());
            this.mapDuplicated.emit();
        } catch (error: any) {
            console.error('Erreur lors de la duplication du jeu:', error);
        }
    }

    async onToggleVisibility(mapId: string): Promise<void> {
        try {
            await this.mapService.toggleMapVisibility(mapId);
        } catch (error: any) {
            console.error('Erreur lors du changement de visibilité:', error);
        }
    }

    async onConfirmDelete(mapId: string): Promise<void> {
        try {
            await this.mapService.deleteMap(mapId);
        } catch (error: any) {
            console.error('Erreur lors de la suppression de la carte:', error);
        }
        this.onCloseDeleteModal();
    }

    onCloseDeleteModal(): void {
        this.showDeleteModal = false;
        this.currentMapId = null;
    }

    formatDate(lastModified: Date): string {
        const date = new Date(lastModified);
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');

        return `${year}-${month}-${day} ${hours}:${minutes}`;
    }

    stateInFrench(state: MapState): string {
        switch (state) {
            case MapState.Public:
                return 'Publique';
            case MapState.Private:
                return 'Privé';
            case MapState.Share:
                return 'Privé-Partagé';
            default:
                return '';
        }
    }

    ngOnDestroy(): void {
        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }
}
