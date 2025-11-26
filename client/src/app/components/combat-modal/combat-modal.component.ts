import { Component, Input, OnDestroy, OnInit } from '@angular/core';
import { AudioService } from '@app/services/audio/audio.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CombatCountdownService } from '@app/services/countdown/combat/combat-countdown.service';
import { GameService } from '@app/services/game/game.service';
import { RollResult } from '@common/combat';
import { CombatEvents } from '@common/events/combat.events';
import { Player } from '@common/game';
import { Subscription } from 'rxjs';

@Component({
    standalone: true,
    selector: 'app-combat-modal',
    templateUrl: './combat-modal.component.html',
    styleUrls: ['./combat-modal.component.scss'],
})
export class CombatModalComponent implements OnInit, OnDestroy {
    @Input() player: Player;
    @Input() opponent: Player;
    @Input() isObserver: boolean = false;

    countdown: number;
    combatMessage: string;

    attackTotal: number;
    defenseTotal: number;

    attacking = false;
    isYourTurn: boolean;

    socketSubscription: Subscription = new Subscription();

    constructor(
        private readonly socketService: SocketService,
        private readonly combatCountDownService: CombatCountdownService,
        private readonly gameService: GameService,
        private readonly audioService: AudioService,
    ) {
        this.socketService = socketService;
        this.combatCountDownService = combatCountDownService;
        this.gameService = gameService;
        this.audioService = audioService;
    }

    ngOnInit() {
        this.audioService.playSoundEffect('SFX_Weapon_Attack.mp3', 1);

        this.listenForAttacks();
        this.listenForCombatTurns();
        this.listenForCountdown();
        this.listenForDiceRoll();
    }

    get turnMessage(): string {
        if (this.isObserver) {
            return `Combat en cours...`;
        }
        if (this.isYourTurn) {
            return `C'est à votre tour de jouer!`;
        } else {
            return `${this.opponent.name} est entrain de jouer.`;
        }
    }

    attack(): void {
        if (this.isYourTurn) {
            this.socketService.sendMessage(CombatEvents.Attack, this.gameService.game.id);
            this.isYourTurn = false;
        }
    }

    evade(): void {
        if (this.isYourTurn) {
            this.socketService.sendMessage(CombatEvents.StartEvasion, this.gameService.game.id);
            this.isYourTurn = false;
        }
    }

    isItYourTurn(): boolean {
        return !this.isYourTurn;
    }

    listenForAttacks(): void {
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.AttackSuccess).subscribe((playerAttacked) => {
                if (playerAttacked.socketId === this.opponent.socketId) this.opponent = playerAttacked;
                else if (playerAttacked.socketId === this.player.socketId) this.player = playerAttacked;

                if (this.isObserver) {
                    // Neutral message for observers
                    const attacker = playerAttacked.socketId === this.opponent.socketId ? this.player.name : this.opponent.name;
                    this.combatMessage = `${attacker} a attaqué ${playerAttacked.name}`;
                } else {
                    if (playerAttacked.socketId === this.opponent.socketId) {
                        this.combatMessage = `Vous avez attaqué ${this.opponent.name}`;
                    } else {
                        this.combatMessage = `${this.opponent.name} vous a attaqué`;
                    }
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.AttackFailure).subscribe((playerAttacked) => {
                if (this.isObserver) {
                    // Neutral message for observers
                    this.combatMessage = `${playerAttacked.name} a survécu à une attaque`;
                } else {
                    if (playerAttacked.socketId === this.opponent.socketId) {
                        this.combatMessage = `${playerAttacked.name} a survécu à votre attaque`;
                    } else {
                        this.combatMessage = `Vous avez survécu à une attaque`;
                    }
                }
            }),
        );
    }

    listenForOpponent(): void {
        this.socketSubscription.add(
            this.socketService.listen<Player>(CombatEvents.CurrentPlayer).subscribe((player: Player) => {
                this.opponent = player;
            }),
        );
    }

    listenForCombatTurns(): void {
        this.socketSubscription.add(
            this.socketService.listen(CombatEvents.YourTurnCombat).subscribe(() => {
                this.isYourTurn = true;
            }),
        );
        this.socketSubscription.add(
            this.socketService.listen(CombatEvents.PlayerTurnCombat).subscribe(() => {
                this.isYourTurn = false;
            }),
        );
    }

    listenForDiceRoll(): void {
        this.socketSubscription.add(
            this.socketService.listen<RollResult>(CombatEvents.DiceRolled).subscribe((rollResult) => {
                this.defenseTotal = rollResult.defenseDice;
                this.attackTotal = rollResult.attackDice;
                if (this.isYourTurn) {
                    this.attacking = true;
                } else {
                    this.attackTotal = rollResult.defenseDice;
                    this.defenseTotal = rollResult.attackDice;
                    this.attacking = false;
                }
            }),
        );
    }

    listenForCountdown() {
        this.socketSubscription.add(
            this.combatCountDownService.combatCountdown$.subscribe((timeLeft: number) => {
                this.countdown = timeLeft;
            }),
        );
    }

    ngOnDestroy() {
        this.socketSubscription.unsubscribe();
    }
}
