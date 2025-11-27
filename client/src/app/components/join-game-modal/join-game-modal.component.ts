import { AfterViewInit, Component, ElementRef, OnDestroy, OnInit, QueryList, ViewChildren } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { GameCreationEvents, JoinGameData } from '@common/events/game-creation.events';
import { Game } from '@common/game';
import { Subscription } from 'rxjs';

@Component({
    selector: 'app-join-game-modal',
    standalone: true,
    imports: [FormsModule],
    templateUrl: './join-game-modal.component.html',
    styleUrl: './join-game-modal.component.scss',
})
export class JoinGameModalComponent implements OnInit, AfterViewInit, OnDestroy {
    @ViewChildren('codeInput') codeInputs!: QueryList<ElementRef>;

    code: string[] = ['', '', '', ''];
    gameId: string | null = null;
    errorMessage: string | null = null;
    currentUsername: string | null = null;
    socketSubscription: Subscription = new Subscription();

    constructor(
        private readonly socketService: SocketService,
        private readonly authService: AuthService,
    ) {
        this.socketService = socketService;
        this.authService = authService;
    }

    async ngOnInit(): Promise<void> {
        this.configureJoinGameSocketFeatures();
        await this.loadUserInfo();
    }

    ngAfterViewInit(): void {
        this.focusFirstInput();
    }

    private async loadUserInfo(): Promise<void> {
        const userInfo = await this.authService.getUserInfo();
        this.currentUsername = userInfo.user.username;
    }

    focusFirstInput(): void {
        const firstInput = this.codeInputs.first;
        if (firstInput) {
            firstInput.nativeElement.focus();
        }
    }
    moveToNext(event: any, index: number): void {
        const input = event.target;
        const value = input.value.replace(/[^0-9]/g, '');
        input.value = value;

        if (this.errorMessage) {
            this.errorMessage = null;
        }

        if (value.length === 1 && index < 4) {
            const nextInput = this.codeInputs.toArray()[index];
            if (nextInput) {
                nextInput.nativeElement.focus();
            }
        }
    }

    joinGame(event: any): void {
        const input = event.target;
        const value = input.value.replace(/[^0-9]/g, '');
        input.value = value;

        if (this.code.every((digit) => digit !== '')) {
            const gameCode = this.code.join('');
            this.gameId = gameCode;

            this.socketService.sendMessage(GameCreationEvents.GetGameData, gameCode);
        }
    }

    resetCodeAndFocus(): void {
        this.code = ['', '', '', ''];
        const firstInput = this.codeInputs.first;
        if (firstInput) {
            firstInput.nativeElement.focus();
        }
    }

    configureJoinGameSocketFeatures(): void {
        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.CurrentGame).subscribe(async (game) => {
                const entryFee = game.settings?.entryFee ?? 0;

                if (entryFee > 0) {
                    const userInfo = await this.authService.getUserInfo();
                    const userMoney = userInfo.user.virtualMoney ?? 0;

                    if (userMoney < entryFee) {
                        this.errorMessage = "Vous n'avez pas assez de monnaie virtuelle pour rejoindre cette partie";
                        this.resetCodeAndFocus();
                        return;
                    }
                }

                const existingPlayer = game.players.find((plyr) => plyr.name === this.currentUsername);
                if (existingPlayer) {
                    const joinGameData: JoinGameData = { player: existingPlayer, gameId: game.id! };
                    this.socketService.sendMessage(GameCreationEvents.ResumeGame, joinGameData);
                } else {
                    this.socketService.sendMessage(GameCreationEvents.AccessGame, game.id);
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameNotFound).subscribe((reason) => {
                if (reason) {
                    this.errorMessage = reason;
                    this.resetCodeAndFocus();
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameLocked).subscribe((reason) => {
                if (reason) {
                    this.errorMessage = reason;
                    this.resetCodeAndFocus();
                }
            }),
        );
    }

    ngOnDestroy(): void {
        this.socketSubscription.unsubscribe();
    }
}
