import { Component, EventEmitter, Input, OnDestroy, OnInit, Output, ViewChild } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { CreateMapModalComponent } from '@app/components/create-map-modal/create-map-modal.component';
import { ErrorMessageComponent } from '@app/components/error-message-component/error-message.component';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { MapService } from '@app/services/map/map.service';
import { DetailedMap, MapState } from '@common/map.types';
import { Subject, takeUntil } from 'rxjs';

@Component({
    selector: 'app-admin-page',
    standalone: true,
    templateUrl: './admin-page.component.html',
    styleUrls: ['./admin-page.component.scss'],
    imports: [ErrorMessageComponent, CreateMapModalComponent, ChatroomComponent],
})
export class AdminPageComponent implements OnInit, OnDestroy {
    @Input() mapId: string = '';
    @Output() importError = new EventEmitter<string>();
    @ViewChild(CreateMapModalComponent, { static: false }) createMapModalComponent!: CreateMapModalComponent;
    @ViewChild(ErrorMessageComponent, { static: false }) errorMessageModal: ErrorMessageComponent;

    maps: DetailedMap[] = [];
    currentMapId: string | null = null;
    showDeleteModal = false;
    isCreateMapModalVisible = false;
    isChatVisible: boolean = false;

    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly router: Router,
        private readonly communicationMapService: CommunicationMapService,
        private readonly mapService: MapService,
    ) {
        this.router = router;
        this.communicationMapService = communicationMapService;
        this.mapService = mapService;
    }

    navigateToMain(): void {
        this.router.navigate(['/main-menu']);
    }

    ngOnInit(): void {
        this.communicationMapService
            .basicGet<DetailedMap[]>('admin')
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe((maps: DetailedMap[]) => (this.maps = maps));
    }

    toggleGameCreationModalVisibility(): void {
        this.isCreateMapModalVisible = true;
    }

    onCloseModal(): void {
        this.isCreateMapModalVisible = false;
    }

    editMap(map: DetailedMap): void {
        this.router.navigate([`/edition/${map._id}`]);
    }

    async deleteMap(mapId: string): Promise<void> {
        try {
            await this.mapService.deleteMap(mapId);
            this.updateDisplay();
        } catch (error: any) {
            let errorMessage = 'Erreur lors de la suppression de la carte';
            if (error.error) {
                try {
                    const errorObj = typeof error.error === 'string' ? JSON.parse(error.error) : error.error;
                    errorMessage = errorObj.message || errorMessage;
                } catch (e) {
                    // Ignore parsing error, use default message
                }
            }
            this.errorMessageModal.open(errorMessage);
        }
    }

    async duplicateMap(map: DetailedMap): Promise<void> {
        try {
            await this.mapService.duplicateMap(map._id.toString());
            this.updateDisplay();
        } catch (error: any) {
            let errorMessage = 'Erreur lors de la duplication du jeu';
            if (error.error) {
                try {
                    const errorObj = typeof error.error === 'string' ? JSON.parse(error.error) : error.error;
                    errorMessage = errorObj.message || errorMessage;
                } catch (e) {
                    // Ignore parsing error, use default message
                }
            }
            this.errorMessageModal.open(errorMessage);
        }
    }

    openConfirmationModal(map: DetailedMap): void {
        this.currentMapId = map._id.toString();
        this.showDeleteModal = true;
    }

    closeDeleteModal(): void {
        this.showDeleteModal = false;
        this.currentMapId = null;
    }

    confirmDelete(mapId: string): void {
        this.deleteMap(mapId);
        this.closeDeleteModal();
    }

    updateDisplay(): void {
        this.communicationMapService
            .basicGet<DetailedMap[]>('admin')
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe((maps: DetailedMap[]) => {
                this.maps = maps;
            });
    }

    toggleVisibility(mapId: string): void {
        this.communicationMapService
            .basicPatch(`admin/${mapId}`)
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe(() => this.updateDisplay());
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
                return 'Privée';
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
