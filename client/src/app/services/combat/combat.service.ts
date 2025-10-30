import { Injectable } from '@angular/core';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { ProfileType, TIME_LIMIT_DELAY } from '@common/constants';
import { CombatEvents, CombatStartedData, PlayerEnteredObservationModeData } from '@common/events/combat.events';
import { Player } from '@common/game';
import { BehaviorSubject, Subscription } from 'rxjs';

@Injectable({
    providedIn: 'root',
})
export class CombatService {
    defaultPlayer: Player = {
        socketId: '',
        name: '',
        avatar: 1,
        isActive: false,
        isObservationMode: false,
        specs: {
            evasions: 2,
            life: 0,
            speed: 0,
            attack: 0,
            defense: 0,
            attackBonus: 4,
            defenseBonus: 4,
            movePoints: 0,
            actions: 0,
            nVictories: 0,
            nDefeats: 0,
            nCombats: 0,
            nEvasions: 0,
            nLifeTaken: 0,
            nLifeLost: 0,
            nItemsUsed: 0,
        },
        inventory: [],
        position: { x: 0, y: 0 },
        initialPosition: { x: 0, y: 0 },
        turn: 0,
        visitedTiles: [],
        profile: ProfileType.NORMAL,
    };

    socketSubscription: Subscription = new Subscription();

    private readonly isCombatModalOpen = new BehaviorSubject<boolean>(false);
    public isCombatModalOpen$ = this.isCombatModalOpen.asObservable();

    private readonly opponent = new BehaviorSubject<Player>(this.defaultPlayer);
    public opponent$ = this.opponent.asObservable();

    private readonly combatPlayer = new BehaviorSubject<Player>(this.defaultPlayer);
    public combatPlayer$ = this.combatPlayer.asObservable();

    private readonly showObservationModeModal = new BehaviorSubject<boolean>(false);
    public showObservationModeModal$ = this.showObservationModeModal.asObservable();

    private readonly observationModeMessage = new BehaviorSubject<string>('');
    public observationModeMessage$ = this.observationModeMessage.asObservable();

    constructor(
        private readonly socketService: SocketService,
        private readonly playerService: PlayerService,
    ) {
        this.socketService = socketService;
        this.playerService = playerService;
    }

    listenCombatStart() {
        this.socketSubscription.add(
            this.socketService.listen<CombatStartedData>(CombatEvents.CombatStarted).subscribe((data) => {
                const currentPlayer = this.playerService.player;
                
                // Check if this player is actually in the combat or just observing
                const isParticipant = currentPlayer.socketId === data.challenger.socketId || 
                                     currentPlayer.socketId === data.opponent.socketId;
                
                
                if (isParticipant) {
                    // Player is in the combat
                    if (currentPlayer.socketId === data.challenger.socketId) {
                        this.opponent.next(data.opponent);
                    } else {
                        this.opponent.next(data.challenger);
                    }
                    this.isCombatModalOpen.next(true);
                } else if (currentPlayer.isObservationMode) {
                    // Player is observing - set both combatants
                    this.combatPlayer.next(data.challenger);
                    this.opponent.next(data.opponent);
                    this.isCombatModalOpen.next(true);
                }
            }),
        );
    }

    listenForCombatFinish(): void {
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.CombatFinishedNormally).subscribe(() => {
                setTimeout(() => {
                    this.isCombatModalOpen.next(false);
                }, TIME_LIMIT_DELAY);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.CombatFinishedByDisconnection).subscribe(() => {
                setTimeout(() => {
                    this.isCombatModalOpen.next(false);
                }, TIME_LIMIT_DELAY);
            }),
        );
    }

    listenForEvasionInfo(): void {
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.EvasionSuccess).subscribe(() => {
                setTimeout(() => {
                    this.isCombatModalOpen.next(false);
                }, TIME_LIMIT_DELAY);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.EvasionFailed).subscribe((evadingPlayer) => {
                if (evadingPlayer.socketId === this.playerService.player.socketId) {
                    this.playerService.setPlayer(evadingPlayer);
                } else {
                    this.opponent.next(evadingPlayer);
                }
            }),
        );
    }

    listenForObservationMode(): void {
        this.socketSubscription.add(
            this.socketService.listen<PlayerEnteredObservationModeData>(CombatEvents.PlayerEnteredObservationMode).subscribe((data) => {
                this.isCombatModalOpen.next(false);
                this.playerService.setPlayer(data.player);
                this.observationModeMessage.next(data.message || 'Vous êtes maintenant en mode observation.');
                this.showObservationModeModal.next(true);
            }),
        );
    }

    closeObservationModeModal(): void {
        this.showObservationModeModal.next(false);
    }
}
