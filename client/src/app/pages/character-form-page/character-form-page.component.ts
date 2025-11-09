import { CommonModule } from '@angular/common';
import { Component, ElementRef, HostListener, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { Character } from '@app/interfaces/character';
import { AuthService } from '@app/services/auth/auth.service';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { CharacterService } from '@app/services/character/character.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { GameService } from '@app/services/game/game.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { TIME_REDIRECTION } from '@common/constants';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents, JoinGameData } from '@common/events/game-creation.events';
import { Bonus, Game, Player } from '@common/game';
import { Map } from '@common/map.types';
import { UserStatus } from '@common/user-friends';
import { firstValueFrom, Subscription } from 'rxjs';
@Component({
    selector: 'app-character-form-page',
    standalone: true,
    imports: [CommonModule, FormsModule, ChatroomComponent],
    templateUrl: './character-form-page.component.html',
    styleUrls: ['./character-form-page.component.scss'],
})
export class CharacterFormPageComponent implements OnInit, OnDestroy {
    @ViewChild('nameInput') nameInput: ElementRef;
    socketSubscription: Subscription = new Subscription();
    Bonus = Bonus;
    name: string = '';
    isEditing: boolean = false;
    isChatVisible: boolean = false;

    lifeOrSpeedBonus: 'life' | 'speed';
    attackOrDefenseBonus: 'attack' | 'defense';

    selectedCharacter: Character;
    currentIndex: number;

    game: Game | undefined;
    gameId: string | null = null;
    mapName: string | null = null;
    gameSettings: { isFastElimination: boolean; isDropInOut: boolean } = { isFastElimination: false, isDropInOut: false };

    gameHasStarted: boolean = false;
    gameLockedModal: boolean = false;
    isJoiningGame: boolean = false;

    showSelectionError: boolean = false;
    showCharacterNameError: boolean = false;
    showBonusError: boolean = false;
    showDiceError: boolean = false;

    showGameStartedModal: boolean = false;

    constructor(
        private readonly communicationMapService: CommunicationMapService,
        private readonly socketService: SocketService,
        private readonly playerService: PlayerService,
        private readonly characterService: CharacterService,
        private readonly router: Router,
        private readonly route: ActivatedRoute,
        private readonly authService: AuthService,
        private readonly gameService: GameService,
        private readonly challengeService: ChallengeService,
    ) {
        this.communicationMapService = communicationMapService;
        this.socketService = socketService;
        this.playerService = playerService;
        this.characterService = characterService;
        this.router = router;
        this.route = route;
        this.authService = authService;
        this.gameService = gameService;
        this.challengeService = challengeService;
    }

    async ngOnInit(): Promise<void> {
        this.playerService.resetPlayer();
        const userInfo = await this.authService.getUserInfo();
        this.name = userInfo?.user?.username || 'Joueur';
        this.playerService.setPlayerName(this.name);

        this.selectedCharacter = this.characters[0];
        this.currentIndex = 0;

        // Reinitialize challenge listeners when entering character creation
        // This ensures listeners are ready after leaving a previous game
        this.challengeService.reinitializeListeners();

        if (!this.router.url.includes('create-game')) {
            this.listenToGameStatus();
            this.listenToPlayerJoin();
            this.isJoiningGame = true;
            this.gameId = this.route.snapshot.params['gameId'];
            this.socketService.sendMessage(GameCreationEvents.GetGameData, this.gameId);
            this.socketService.sendMessage(GameCreationEvents.GetPlayers, this.gameId);
        } else {
            this.mapName = this.route.snapshot.params['mapName'];
            // Get game settings from navigation state
            if (window.history.state?.gameSettings) {
                this.gameSettings = window.history.state.gameSettings;
            }
        }
    }

    get life(): number {
        return this.playerService.player.specs.life;
    }

    get speed(): number {
        return this.playerService.player.specs.speed;
    }

    get attack(): number {
        return this.playerService.player.specs.attack;
    }

    get defense(): number {
        return this.playerService.player.specs.defense;
    }

    get attackBonus(): Bonus {
        return this.playerService.player.specs.attackBonus;
    }

    get defenseBonus(): Bonus {
        return this.playerService.player.specs.defenseBonus;
    }

    get characters(): Character[] {
        return this.characterService.characters;
    }

    listenToGameStatus(): void {
        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameLocked).subscribe(() => {
                this.gameLockedModal = true;
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameCreated).subscribe((game) => {
                this.gameId = game.id;
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<string>(GameCreationEvents.GameAlreadyStarted).subscribe(() => {
                this.showGameStartedModal = true;
                setTimeout(() => {
                    this.characterService.resetCharacterAvailability();
                    this.router.navigate(['/main-menu']);
                }, TIME_REDIRECTION);
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.CurrentGame).subscribe((game) => {
                if (game) {
                    this.game = game;
                    if (game.settings) {
                        this.gameSettings = game.settings;
                    }
                    if (game.hasStarted) {
                        this.gameHasStarted = true;
                    }
                }
            }),
        );
    }

    listenToPlayerJoin(): void {
        this.socketSubscription.add(
            this.socketService
                .listen<{ updatedPlayer: Player; updatedGame: Game }>(GameCreationEvents.YouJoined)
                .subscribe(({ updatedPlayer, updatedGame }) => {
                    this.playerService.setPlayer(updatedPlayer);
                    if (updatedPlayer.isObservationMode || (this.gameSettings.isDropInOut && this.gameHasStarted)) {
                        if (updatedGame) {
                            this.gameService.setGame(updatedGame);
                            this.router.navigate([`/game/${updatedGame.id}/${updatedGame.name}`], {
                                state: { player: this.playerService.player, gameId: updatedGame.id },
                            });
                        }
                    } else {
                        this.router.navigate([`${this.gameId}/waiting-room/player`]);
                    }
                    this.socketService.sendMessage(FriendsEvents.UpdateUserStatus, { status: UserStatus.InGame });
                }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Player[]>(GameCreationEvents.CurrentPlayers).subscribe((players: Player[]) => {
                this.characters.forEach((character) => {
                    character.isAvailable = true;
                    if (players.some((player) => player.avatar === character.id)) {
                        character.isAvailable = false;
                    }
                });
                if (!this.selectedCharacter.isAvailable) {
                    for (let i = 0; i < this.characters.length; i++) {
                        if (this.characters[i].isAvailable) {
                            this.selectedCharacter = this.characters[i];
                            this.playerService.setPlayerAvatar(this.selectedCharacter.id);
                            this.currentIndex = i;
                            break;
                        }
                    }
                }
            }),
        );

        this.socketSubscription.add(
            this.socketService.listen<Game>(GameCreationEvents.GameUpdated).subscribe((game) => {
                this.gameService.setGame(game);
                // this.activePlayers = game.players.filter((p) => p.isActive);
            }),
        );
    }

    selectCharacter(character: Character) {
        if (character.isAvailable) {
            this.selectedCharacter = character;
            this.playerService.setPlayerAvatar(character.id);
        }
    }

    previousCharacter() {
        do {
            this.currentIndex = this.currentIndex === 0 ? this.characters.length - 1 : this.currentIndex - 1;
        } while (!this.characters[this.currentIndex].isAvailable);
        this.selectedCharacter = this.characters[this.currentIndex];
    }

    nextCharacter() {
        do {
            this.currentIndex = this.currentIndex === this.characters.length - 1 ? 0 : this.currentIndex + 1;
        } while (!this.characters[this.currentIndex].isAvailable);
        this.selectedCharacter = this.characters[this.currentIndex];
    }

    addBonus(bonusType: 'life' | 'speed'): void {
        this.lifeOrSpeedBonus = bonusType;
        this.playerService.assignBonus(this.lifeOrSpeedBonus);
    }

    assignDice(bonusType: 'attack' | 'defense'): void {
        this.attackOrDefenseBonus = bonusType;
        this.playerService.assignDice(this.attackOrDefenseBonus);
    }

    async onSubmit() {
        if (this.gameLockedModal) {
            this.gameLockedModal = false;
        }
        if (this.verifyErrors()) {
            this.playerService.createPlayer();

            if (this.router.url.includes('create-game')) {
                try {
                    const chosenMap = await firstValueFrom(this.communicationMapService.basicGet<Map>(`map/${this.mapName}`));
                    if (!chosenMap) {
                        this.showSelectionError = true;
                        setTimeout(() => {
                            this.router.navigate(['/create-game']);
                        }, TIME_REDIRECTION);
                    } else {
                        this.socketService.sendMessage(FriendsEvents.UpdateUserStatus, { status: UserStatus.InGame });
                        this.router.navigate([`${this.mapName}/waiting-room/host`], {
                            state: { gameSettings: this.gameSettings },
                        });
                    }
                } catch (error) {
                    this.showSelectionError = true;
                    setTimeout(() => {
                        this.router.navigate(['/create-game']);
                    }, TIME_REDIRECTION);
                }
            } else if (window.history.state?.isObserver) {
                this.playerService.player.isActive = false;
                this.playerService.player.isObservationMode = true;
                const joinGameData: JoinGameData = { player: this.playerService.player, gameId: this.gameId! };
                this.socketService.sendMessage(GameCreationEvents.ObserveGame, joinGameData);
            } else {
                const joinGameData: JoinGameData = { player: this.playerService.player, gameId: this.gameId! };
                this.socketService.sendMessage(GameCreationEvents.JoinGame, joinGameData);
            }
        }
    }

    onReturn() {
        if (!this.router.url.includes('create-game')) {
            this.router.navigate(['/main-menu']);
        } else {
            this.router.navigate(['/create-game']);
        }
    }

    verifyErrors(): boolean {
        this.showSelectionError = false;
        this.showCharacterNameError = false;
        this.showBonusError = false;
        this.showDiceError = false;

        if (this.name === 'Choisis un nom' || this.playerService.player.name === '') {
            this.showCharacterNameError = true;
            return false;
        }

        if (!this.lifeOrSpeedBonus) {
            this.showBonusError = true;
            return false;
        }

        if (!this.attackOrDefenseBonus) {
            this.showDiceError = true;
            return false;
        }
        return true;
    }

    onQuit() {
        this.socketService.disconnect();
        this.characterService.resetCharacterAvailability();
        this.router.navigate(['/main-menu'], { state: {} });
    }

    @HostListener('window:keydown', ['$event'])
    handleKeyDown(event: KeyboardEvent): void {
        if (event.key === 'ArrowLeft') {
            this.previousCharacter();
        } else if (event.key === 'ArrowRight') {
            this.nextCharacter();
        }
    }

    ngOnDestroy(): void {
        this.socketSubscription.unsubscribe();
    }
}
