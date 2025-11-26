import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

@Injectable({
    providedIn: 'root',
})
export class AudioService {
    private musicPlayer: HTMLAudioElement | null = null;
    private _equippedMusic = 'music2.mp3';
    private currentlyLoadedMusic: string | null = null;
    private readonly isMusicEnabledSubject = new BehaviorSubject<boolean>(false);
    private readonly areSoundEffectsEnabledSubject = new BehaviorSubject<boolean>(true);
    private readonly isHostControlledSubject = new BehaviorSubject<boolean>(false);
    public musicEnabled$ = this.isMusicEnabledSubject.asObservable();
    public soundEffectsEnabled$ = this.areSoundEffectsEnabledSubject.asObservable();
    public isHostControlled$ = this.isHostControlledSubject.asObservable();

    get isMusicEnabled(): boolean {
        return this.isMusicEnabledSubject.value;
    }

    set musicEnabled(enabled: boolean) {
        this.isMusicEnabledSubject.next(enabled);
        if (enabled) {
            if (this.musicPlayer) {
                this.resumeMusic();
            } else {
                this.playBackgroundMusic(this._equippedMusic);
            }
        } else if (this.musicPlayer) {
            this.pauseMusic();
        }
    }

    get areSoundEffectsEnabled(): boolean {
        return this.areSoundEffectsEnabledSubject.value;
    }

    set areSoundEffectsEnabled(enabled: boolean) {
        this.areSoundEffectsEnabledSubject.next(enabled);
    }

    get equippedMusic(): string {
        return this._equippedMusic;
    }

    playBackgroundMusic(filename: string = this._equippedMusic): void {
        // Stop and recreate player if switching to a different track
        if (this.musicPlayer && this.currentlyLoadedMusic !== filename) {
            this.stopMusic();
            this.musicPlayer = null;
            this.currentlyLoadedMusic = null;
        }

        if (!this.musicPlayer) {
            this.musicPlayer = new Audio(`assets/sounds/${filename}`);
            this.musicPlayer.loop = true;
            this.musicPlayer.volume = 0.5;
            this.currentlyLoadedMusic = filename;
        }

        if (this.isMusicEnabled) {
            this.musicPlayer.play().catch((error) => {
                console.error('Error playing music:', error);
            });
        }
    }

    setEquippedMusic(filename: string): void {
        const wasPlaying = this.musicPlayer && !this.musicPlayer.paused;
        const wasMusicEnabled = this.isMusicEnabled;
        this._equippedMusic = filename;

        if (wasPlaying) {
            // Stop the current player without changing the enabled state
            if (this.musicPlayer) {
                this.musicPlayer.pause();
                this.musicPlayer.currentTime = 0;
                this.currentlyLoadedMusic = null;
            }
            this.musicPlayer = null;
            // Only play if music was enabled
            if (wasMusicEnabled) {
                this.playBackgroundMusic(filename);
            }
        }
    }

    pauseMusic(): void {
        if (this.musicPlayer && !this.musicPlayer.paused) {
            this.musicPlayer.pause();
        }
    }

    resumeMusic(): void {
        if (this.musicPlayer?.paused) {
            this.musicPlayer.play().catch((error) => {
                console.error('Error resuming music:', error);
            });
        }
    }

    stopMusic(): void {
        if (this.musicPlayer) {
            this.musicPlayer.pause();
            this.musicPlayer.currentTime = 0;
            this.currentlyLoadedMusic = null;
        }
        this.isMusicEnabledSubject.next(false);
    }

    playSoundEffect(filename: string, volume: number = 1): void {
        if (!this.areSoundEffectsEnabled) return;
        const sound = new Audio(`assets/sounds/${filename}`);
        sound.volume = volume;
        sound.play().catch((error) => {
            console.error('Error playing sound effect:', error);
        });
    }

    get isHostControlled(): boolean {
        return this.isHostControlledSubject.value;
    }

    setHostControlledSettings(musicEnabled: boolean, sfxEnabled: boolean): void {
        this.isHostControlledSubject.next(true);
        this.musicEnabled = musicEnabled;
        this.areSoundEffectsEnabled = sfxEnabled;
    }

    clearHostControl(): void {
        this.isHostControlledSubject.next(false);
    }
}
