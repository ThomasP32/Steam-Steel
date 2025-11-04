import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { Game, Player } from '@common/game';
import { AuthService } from '@app/services/auth/auth.service';
import { MapConfig, MapSize } from '@common/constants';

@Component({
  selector: 'app-game-preview',
  standalone: true,
  imports: [],
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
  existingParticipant: Player | undefined = undefined;

  constructor(
    private readonly authService: AuthService,
  ) {
    this.authService = authService;
  }    
  async ngOnInit(): Promise<void> {
    await this.loadUserInfo();
  }
  
  get activePlayers(): Player[]{
    if (this.game && this.game.players){
      return this.game.players.filter((plyr) => plyr.isActive);
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
      if(this.game.settings.isFastElimination){
        return this.game.participants.length === this.mapMaxPlayers;
      }
      return this.activePlayers.length === this.mapMaxPlayers;
    }
    return undefined;
  }

  private async loadUserInfo(): Promise<void> {
    const userInfo = await this.authService.getUserInfo();
    this.currentUsername = userInfo.user.username;
    this.existingPlayer = this.game.players.find(plyr => plyr.name === this.currentUsername) ;
    this.existingParticipant = this.game.participants.find(plyr => plyr.name === this.currentUsername) ;
  }

  onJoinClick() {this.join.emit(this.game)}
  onResumeClick() {this.rejoin.emit(this.game)}
  onObserveClick() {this.observe.emit(this.game)}

}
