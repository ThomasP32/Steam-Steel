import { TestBed } from '@angular/core/testing';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { of } from 'rxjs';
import { ChallengeService } from './challenge.service';

describe('ChallengeService', () => {
    let service: ChallengeService;

    beforeEach(() => {
        const spy = jasmine.createSpyObj('SocketService', ['listen']);
        spy.listen.and.returnValue(of({}));

        TestBed.configureTestingModule({
            providers: [ChallengeService, { provide: SocketService, useValue: spy }],
        });
        service = TestBed.inject(ChallengeService);
    });

    it('should be created', () => {
        expect(service).toBeTruthy();
    });

    it('should have challenge$ observable', () => {
        expect(service.challenge$).toBeDefined();
    });

    it('should reset challenge', () => {
        service.resetChallenge();
        service.challenge$.subscribe((challenge) => {
            expect(challenge).toBeNull();
        });
    });
});
