import { Injectable } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private styleEl: HTMLStyleElement | null = null;
  private cache: any | null = null;

  private ensureStyle(): HTMLStyleElement {
    if (!this.styleEl) {
      this.styleEl = document.createElement('style');
      this.styleEl.id = 'theme-style';
      document.head.appendChild(this.styleEl);
    }
    return this.styleEl;
  }
  private removeStyle(){ this.styleEl?.remove(); this.styleEl = null; }
  private asset(id: string){ return `/assets/backgrounds/${id}.png`; }

  async applyThemeJson(name: 'theme-dark'|'theme-light'): Promise<void> {
    if (name !== 'theme-light') { this.removeStyle(); return; }

    if (!this.cache) {
      const res = await fetch('/assets/themes/theme-light.json', { cache: 'no-cache' });
      if (!res.ok) throw new Error('theme-light.json introuvable');
      this.cache = await res.json();
    }
    const t = this.cache;
    const C = t.colors, S = t.selectors, I = t.images;
    const scope = 'app-root.theme-light';
    S.buttons_all = `:is(
      .button, .btn, button, [role="button"],
      input[type="button"], input[type="submit"], a.button
    ):not(
      .unlocked,
      .locked,
      .login-button,
      .sign-up-button,
      .modify-button,
      .delete-button,
      .player_stats,
      .profile-button,
      .create-player-button,
      .no-theme
    )`;
    const css = `
      ${scope} ${S.home}{background:url('${this.asset(I.home_bg)}') center/cover no-repeat fixed !important; min-height:100vh !important;}
      ${scope} ${S.edition}{background:url('${this.asset(I.edition_bg)}') center/cover no-repeat fixed !important; }
      ${scope} ${S.create}, ${scope} ${S.character}, ${scope} ${S.waiting}, ${scope} ${S.game}, ${scope} ${S.admin}, ${scope} ${S.combat_modal}{
        background:url('${this.asset(I.city_bg)}') center/cover no-repeat fixed !important;
      }
      ${scope} ${S.buttons_all}{
        background: ${C.button_bg} !important;
        border: 3px solid ${C.button_border} !important;
        color: ${C.button_text} !important;
        transition: filter .15s ease, transform .05s ease !important;
      }
      ${scope} ${S.buttons_all}:hover{
        filter: brightness(1.05) !important;
      }
      ${scope} ${S.buttons_all}:active{
        filter: brightness(0.9) !important;
        transform: translateY(1px) !important;
      }
      ${scope} ${S.buttons_all}:focus-visible{
        outline: 2px solid ${C.button_border} !important;
        outline-offset: 2px !important;
      }

      ${scope} ${S.chat_toggle}{
        background:${C.chat_toggle_bg} !important; border:3px solid ${C.chat_toggle_border} !important; color:${C.button_text} !important;
      }

      ${scope} ${S.player_count_bar}, ${scope} ${S.gamemode_bar}{
        background:${C.player_count_bar_bg} !important;
      }

      ${scope} ${S.game_map}, ${scope} ${S.game_code}, ${scope} ${S.players_list}{
        background:linear-gradient(135deg, ${C.map_grad_from} 30%, ${C.map_grad_to} 100%) !important;
      }

      ${scope} ${S.info_item}, ${scope} ${S.inventory_slot}{
        background:${C.info_item_bg} !important;
      }
      `.trim();
      this.ensureStyle().textContent = css;
    }
  }
