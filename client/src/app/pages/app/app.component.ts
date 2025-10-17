import { Component, HostBinding } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from '@app/services/theme/theme.service';

@Component({
    selector: 'app-root',
    standalone: true,
    templateUrl: './app.component.html',
    styleUrls: ['./app.component.scss'],
    imports: [RouterOutlet],
})
export class AppComponent {
    @HostBinding('class') themeClass: string = 'theme-dark';
    
    constructor( private themeService: ThemeService) {}

    async toggleTheme() {
        const next = this.themeClass === 'theme-dark' ? 'theme-light' : 'theme-dark';
        try {
            await this.themeService.applyThemeJson(next);
            this.themeClass = next;
        }
        catch (e) {
            console.error('Theme update failed', e);
        }
    }
}
