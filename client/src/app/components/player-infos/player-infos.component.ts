import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { ActionsComponentComponent } from '@app/components/actions-component/actions-component.component';
import { CharacterService } from '@app/services/character/character.service';
import { ImageService } from '@app/services/image/image.service';
import { Player } from '@common/game';

@Component({
    selector: 'app-player-infos',
    standalone: true,
    imports: [ActionsComponentComponent],
    templateUrl: './player-infos.component.html',
    styleUrl: './player-infos.component.scss',
})
export class PlayerInfosComponent implements OnInit {
    @Input() player: Player;
    @Input() currentPlayerTurn: string;
    @Output() showExitModalChange = new EventEmitter<boolean>();

    playerPreview: string = '';
    constructor(
        private readonly characterService: CharacterService,
        protected readonly imageService: ImageService,
    ) {
        this.imageService = imageService;
        this.characterService = characterService;
    }

    ngOnInit(): void {
        this.playerPreview = this.characterService.getAvatarPreview(this.player.avatar);
    }

    onShowExitModalChange(value: boolean): void {
        this.showExitModalChange.emit(value);
    }

    getMaxLife(): number {
        return this.player.specs.life;
    }

    getMaxSpeed(): number {
        return this.player.specs.speed;
    }

    getMaxAttack(): number {
        return this.player.specs.attack;
    }

    getMaxDefense(): number {
        return this.player.specs.defense;
    }
}
