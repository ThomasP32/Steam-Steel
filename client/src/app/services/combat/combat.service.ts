import { Injectable } from '@angular/core';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { ProfileType, TIME_LIMIT_DELAY } from '@common/constants';
import {
    CombatEvents,
    CombatFinishedByEvasionData,
    CombatFinishedData,
    CombatStartedData,
    PlayerEnteredObservationModeData,
} from '@common/events/combat.events';
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
        level: 1,
        isActive: false,
        isEliminated: false,
        isObserver: false,
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
    isEvasion: boolean = false;
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

    private readonly isCombatOngoing = new BehaviorSubject<boolean>(false);
    public isCombatOngoing$ = this.isCombatOngoing.asObservable();

    private readonly showCombatResultModal = new BehaviorSubject<boolean>(false);
    public showCombatResultModal$ = this.showCombatResultModal.asObservable();

    private readonly combatWinner = new BehaviorSubject<[Player, boolean] | null>(null);
    public combatWinner$ = this.combatWinner.asObservable();

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
                const isParticipant = currentPlayer.socketId === data.challenger.socketId || currentPlayer.socketId === data.opponent.socketId;

                if (isParticipant) {
                    // Player is in the combat
                    if (currentPlayer.socketId === data.challenger.socketId) {
                        this.opponent.next(data.opponent);
                    } else {
                        this.opponent.next(data.challenger);
                    }
                    this.isCombatModalOpen.next(true);
                } else if (currentPlayer.isEliminated === true || currentPlayer.isObserver === true) {
                    // Player is observing - set both combatants
                    this.combatPlayer.next(data.challenger);
                    this.opponent.next(data.opponent);
                    this.isCombatModalOpen.next(true);
                }
            }),
        );

        // Listen for combat signal sent to non-participants
        this.socketSubscription.add(
            this.socketService.listen(CombatEvents.CombatStartedSignal).subscribe(() => {
                // Show notification for active players not in the combat
                if (!this.isCombatModalOpen.value) {
                    this.isCombatOngoing.next(true);
                }
            }),
        );
    }

    listenForCombatFinish(): void {
        this.socketSubscription.add(
            this.socketService.listen<CombatFinishedData>(CombatEvents.CombatFinished).subscribe((data) => {
                this.isCombatModalOpen.next(false);
                this.isCombatOngoing.next(false);

                // Show combat result modal for 2 seconds
                this.isEvasion = false;
                this.combatWinner.next([data.winner, this.isEvasion]);
                this.showCombatResultModal.next(true);
                setTimeout(() => {
                    this.showCombatResultModal.next(false);
                    this.combatWinner.next(null);
                }, 2000);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.CombatFinishedNormally).subscribe(() => {
                setTimeout(() => {
                    this.isCombatModalOpen.next(false);
                    this.isCombatOngoing.next(false);
                }, TIME_LIMIT_DELAY);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.CombatFinishedByDisconnection).subscribe(() => {
                setTimeout(() => {
                    this.isCombatModalOpen.next(false);
                    this.isCombatOngoing.next(false);
                }, TIME_LIMIT_DELAY);
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen<CombatFinishedByEvasionData>(CombatEvents.CombatFinishedByEvasion).subscribe((data) => {
                this.isCombatModalOpen.next(false);
                this.isCombatOngoing.next(false);

                this.isEvasion = true;
                this.combatWinner.next([data.evadingPlayer, this.isEvasion]);
                this.showCombatResultModal.next(true);
                setTimeout(() => {
                    this.showCombatResultModal.next(false);
                    this.combatWinner.next(null);
                }, 2000);
            }),
        );
        // Also listen for game finish to close combat modal when the entire game ends
        this.socketSubscription.add(
            this.socketService.listen(CombatEvents.GameFinished).subscribe(() => {
                this.isCombatModalOpen.next(false);
                this.isCombatOngoing.next(false);
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

    closeCombatModal(): void {
        this.isCombatModalOpen.next(false);
        this.isCombatOngoing.next(false);
    }

    closeCombatResultModal(): void {
        this.showCombatResultModal.next(false);
        this.combatWinner.next(null);
    }

    /**
     * Resets all combat state when leaving a game.
     * This ensures the combat modal from a previous game doesn't appear in a new game.
     */
    resetCombatState(): void {
        this.isCombatModalOpen.next(false);
        this.isCombatOngoing.next(false);
        this.opponent.next(this.defaultPlayer);
        this.combatPlayer.next(this.defaultPlayer);
        this.showObservationModeModal.next(false);
        this.observationModeMessage.next('');
        
        // Unsubscribe from all combat event listeners to prevent receiving events from old game
        if (this.socketSubscription) {
            this.socketSubscription.unsubscribe();
            this.socketSubscription = new Subscription();
        }
    }
}
