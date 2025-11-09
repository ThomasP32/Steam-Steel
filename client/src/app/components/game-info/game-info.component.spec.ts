import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MapConversionService } from '@app/services/map-conversion/map-conversion.service';
import { GameInfoComponent } from './game-info.component';

describe('GameInfoComponent', () => {
    let component: GameInfoComponent;
    let fixture: ComponentFixture<GameInfoComponent>;

    beforeEach(async () => {
        await TestBed.configureTestingModule({
            imports: [GameInfoComponent],
            providers: [MapConversionService],
        }).compileComponents();

        fixture = TestBed.createComponent(GameInfoComponent);
        component = fixture.componentInstance;
    });

    it('should create', () => {
        expect(component).toBeTruthy();
    });
});

