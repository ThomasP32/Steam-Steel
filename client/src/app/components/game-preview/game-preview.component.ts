import { NgClass } from '@angular/common';
import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { AuthService } from '@app/services/auth/auth.service';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { MapConfig, MapSize } from '@common/constants';
import { Game, Player } from '@common/game';
import { A11yModule } from "@angular/cdk/a11y";

@Component({
  selector: 'app-game-preview',
  standalone: true,
  imports: [NgClass, A11yModule],
  templateUrl: './game-preview.component.html',
  styleUrl: './game-preview.component.scss'
})
export class GamePreviewComponent implements OnInit {
  @Input() game: Game ;
  @Output() join = new EventEmitter<Game>();
  @Output() rejoin = new EventEmitter<Game>();
  @Output() observe = new EventEmitter<Game>();

  errorMessage: string | null = null;
  currentUsername: string = '';
  existingPlayer : Player | undefined = undefined;

  constructor(
    private readonly authService: AuthService,
    private readonly mapConversionService: MapConversionService,
  ) {
    this.authService = authService;
    this.mapConversionService = mapConversionService;
  }    
  async ngOnInit(): Promise<void> {
    await this.loadUserInfo();
  }
  
  get activePlayers(): Player[]{
    if (this.game && this.game.players){
      return this.game.players.filter((plyr) => plyr.isActive || plyr.isEliminated);
    }
    return [];
  }

  get mapMaxPlayers(): number | undefined {
    if(this.game) {
      const mapSize = Object.values(MapSize).find((size) => MapConfig[size].size === this.game.mapSize.x);
      return mapSize && MapConfig[mapSize].maxPlayers;
    }
    return undefined;
  }

  get isFull(): boolean | undefined {
    if(this.game) {
      // Count active + eliminated players to determine capacity
      const activeOrEliminatedCount = this.game.players.filter((p) => p.isActive || p.isEliminated).length;
      return activeOrEliminatedCount >= (this.mapMaxPlayers ?? 0);
    }
    return undefined;
  }

  get wasInGameAsPlayer(): boolean {
    return this.existingPlayer !== undefined && !this.existingPlayer.isObserver;
  }

  private async loadUserInfo(): Promise<void> {
    const userInfo = await this.authService.getUserInfo();
    this.currentUsername = userInfo.user.username;
    this.existingPlayer = this.game.players.find(plyr => plyr.name === this.currentUsername) ;
  }

  convertMapSize(value: number): string {
    return this.mapConversionService.convertNumberToString(value);
  }

  onJoinClick() {this.join.emit(this.game)}
  onResumeClick() {this.rejoin.emit(this.game)}
  onObserveClick() {this.observe.emit(this.game)}

}
