import { ComponentFixture, TestBed } from '@angular/core/testing';
import { GameOptionsModalComponent } from './game-options-modal.component';

describe('GameOptionsModalComponent', () => {
    let component: GameOptionsModalComponent;
    let fixture: ComponentFixture<GameOptionsModalComponent>;

    beforeEach(async () => {
        await TestBed.configureTestingModule({
            imports: [GameOptionsModalComponent],
        }).compileComponents();

        fixture = TestBed.createComponent(GameOptionsModalComponent);
        component = fixture.componentInstance;
        fixture.detectChanges();
    });

    it('should create', () => {
        expect(component).toBeTruthy();
    });

    it('should emit closed event when onClose is called', () => {
        spyOn(component.closed, 'emit');
        component.onClose();
        expect(component.closed.emit).toHaveBeenCalled();
    });

    it('should emit next event with game settings when onNext is called', () => {
        spyOn(component.next, 'emit');
        component.isFastElimination = true;
        component.onNext();
        expect(component.next.emit).toHaveBeenCalledWith({ isFastElimination: true });
    });

    it('should toggle fast elimination mode', () => {
        expect(component.isFastElimination).toBe(false);
        component.toggleFastElimination();
        expect(component.isFastElimination).toBe(true);
        component.toggleFastElimination();
        expect(component.isFastElimination).toBe(false);
    });
});

