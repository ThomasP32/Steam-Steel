import { Component, EventEmitter, Input, OnDestroy, OnInit, Output, ViewChild } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { CreateMapModalComponent } from '@app/components/create-map-modal/create-map-modal.component';
import { ErrorMessageComponent } from '@app/components/error-message-component/error-message.component';
import { MapListComponent } from '@app/components/map-list/map-list.component';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { AdminEvents } from '@common/events/admin.events';

import { DetailedMap, MapState } from '@common/map.types';
import { Subject, takeUntil } from 'rxjs';

@Component({
    selector: 'app-admin-page',
    standalone: true,
    templateUrl: './admin-page.component.html',
    styleUrls: ['./admin-page.component.scss'],
    imports: [ErrorMessageComponent, CreateMapModalComponent, ChatroomComponent, MapListComponent],
})
export class AdminPageComponent implements OnInit, OnDestroy {
    @Input() mapId: string = '';
    @Output() importError = new EventEmitter<string>();
    @ViewChild(CreateMapModalComponent, { static: false }) createMapModalComponent!: CreateMapModalComponent;
    @ViewChild(ErrorMessageComponent, { static: false }) errorMessageModal: ErrorMessageComponent;

    maps: DetailedMap[] = [];
    myMaps: DetailedMap[] = [];
    publicMaps: DetailedMap[] = [];
    isCreateMapModalVisible = false;
    isChatVisible: boolean = false;
    currentUsername: string = '';
    currentUserId: string = '';

    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly router: Router,
        private readonly communicationMapService: CommunicationMapService,
        private readonly authService: AuthService,
        private readonly socketService: SocketService,
    ) {
        this.router = router;
        this.communicationMapService = communicationMapService;
        this.authService = authService;
        this.socketService = socketService;
    }

    navigateToMain(): void {
        this.router.navigate(['/main-menu']);
    }

    async ngOnInit(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            this.currentUsername = userInfo.user.username;
            this.currentUserId = userInfo.user._id;
        } catch (error) {
            console.error('Erreur lors de la récupération des informations utilisateur:', error);
        }

        this.communicationMapService
            .basicGet<DetailedMap[]>('admin')
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe((maps: DetailedMap[]) => {
                this.maps = maps;
                this.separateMaps();
            });

        this.socketService
            .listen<void>(AdminEvents.MapListUpdated)
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe(() => {
                this.updateDisplay();
            });
    }

    toggleGameCreationModalVisibility(): void {
        this.isCreateMapModalVisible = true;
    }

    onCloseModal(): void {
        this.isCreateMapModalVisible = false;
    }

    updateDisplay(): void {
        this.communicationMapService
            .basicGet<DetailedMap[]>('admin')
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe((maps: DetailedMap[]) => {
                this.maps = maps;
                this.separateMaps();
            });
    }

    private separateMaps(): void {
        this.myMaps = this.maps.filter((map) => map.creator === this.currentUserId);
        this.publicMaps = this.maps.filter((map) => map.state === MapState.Public && map.creator !== this.currentUserId);
    }

    scrollToTop(): void {
        const scrollableContainer = document.querySelector('.scrollable-container');
        if (scrollableContainer) {
            scrollableContainer.scrollTo({
                top: 0,
                behavior: 'smooth',
            });
        } else {
            window.scrollTo({
                top: 0,
                behavior: 'smooth',
            });
        }
    }

    ngOnDestroy(): void {
        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }
}
