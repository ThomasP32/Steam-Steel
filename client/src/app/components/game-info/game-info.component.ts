import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { Game } from '@common/game';

@Component({
    selector: 'app-game-info',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './game-info.component.html',
    styleUrl: './game-info.component.scss',
})
export class GameInfoComponent {
    @Input() game: Game;
    @Input() currentPlayerTurn: string | null;

    constructor(protected readonly mapConversionService: MapConversionService) {
        this.mapConversionService = mapConversionService;
    }

    convertMapSize(value: number): string {
        return this.mapConversionService.convertNumberToString(value);
    }

    get totalPlayerCount(): number {
        if (!this.game?.players) {
            return 0;
        }
        return this.game.players.filter(
            (player) => player.isActive || player.isEliminated
        ).length;
    }
}
