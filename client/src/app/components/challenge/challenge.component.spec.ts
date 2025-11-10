import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { of } from 'rxjs';
import { ChallengeComponent } from './challenge.component';

describe('ChallengeComponent', () => {
    let component: ChallengeComponent;
    let fixture: ComponentFixture<ChallengeComponent>;

    beforeEach(async () => {
        const spy = jasmine.createSpyObj('ChallengeService', ['resetChallenge'], {
            challenge$: of(null),
        });

        await TestBed.configureTestingModule({
            imports: [ChallengeComponent],
            providers: [{ provide: ChallengeService, useValue: spy }],
        }).compileComponents();

        fixture = TestBed.createComponent(ChallengeComponent);
        component = fixture.componentInstance;
        fixture.detectChanges();
    });

    it('should create', () => {
        expect(component).toBeTruthy();
    });

    it('should subscribe to challenge$ on init', () => {
        expect(component.challenge).toBeNull();
    });

    it('should calculate progress percentage correctly', () => {
        component.challenge = {
            title: 'Test Challenge',
            description: 'Test Description',
            reward: 100,
            progress: 0.75,
            completed: false,
        };
        expect(component.getProgressPercentage()).toBe(75);
    });

    it('should return 0 progress when challenge is null', () => {
        component.challenge = null;
        expect(component.getProgressPercentage()).toBe(0);
    });

    it('should unsubscribe on destroy', () => {
        spyOn(component['subscription'], 'unsubscribe');
        component.ngOnDestroy();
        expect(component['subscription'].unsubscribe).toHaveBeenCalled();
    });
});

