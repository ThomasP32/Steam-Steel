import { Injectable } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ThemeService {
    private styleEl: HTMLStyleElement | null = null;
    private cache: any | null = null;
    currentTheme: 'theme-dark' | 'theme-light' = 'theme-dark';

    private ensureStyle(): HTMLStyleElement {
        if (!this.styleEl) {
            this.styleEl = document.createElement('style');
            this.styleEl.id = 'theme-style';
            document.head.appendChild(this.styleEl);
        }
        return this.styleEl;
    }
    private removeStyle() {
        this.styleEl?.remove();
        this.styleEl = null;
    }
    private asset(id: string) {
        return `assets/backgrounds/${id}.png`;
    }

    async applyThemeJson(name: 'theme-dark' | 'theme-light'): Promise<void> {
        if (name !== 'theme-light') {
            this.removeStyle();
            this.currentTheme = 'theme-dark';
            return;
        }
        this.currentTheme = 'theme-light';

        if (!this.cache) {
            const res = await fetch('assets/themes/theme-light.json', { cache: 'no-cache' });
            if (!res.ok) throw new Error('theme-light.json introuvable');
            this.cache = await res.json();
        }
        const t = this.cache;
        const C = t.colors,
            S = t.selectors,
            I = t.images;
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
      .join-actions button,
      .remove-friend-btn,
      .add-friend-btn-list,
      .accept-btn,
      .reject-btn,
      .tab-button,
      .close-btn,
      .close-button,
      .action-button,
      .buy-btn,
      .equip-btn,
      .action-btn,
      .item-actions,
      .category-btn,
      .alert-button,
      .invite-friends-button,
      .game-status,
      .kick-button,
      .action-button next-button,
      .action-button back-button,
      .action-button accept-button,
      .action-button reject-button,
      .add-player-btn,
      .duplicate-button,
      .map-delete,
      .edit-button,
      .to-edit-button,
      .map-button,
      .mode-button,
      .save-button,
      .toggle-section button,
      .button-section button,
      .bonus-button,
      .dice-button,
      .levelup-action button,
      .exit-button-container button,
      .channel-actions button,
      .create-btn,
      .host-waiting .button-container button,
      .start-button,
      .channel-button,
      .toggle-theme-btn,
      .filters-btn,
      .order-btn,
      .no-theme
    )`;
        const css = `
         ${scope} { --profile-button-hover: ${C.profile_button_hover || C.friends_border_accent}; }
      ${scope} ${S.home}{background:url('${this.asset(I.home_bg)}') center/cover no-repeat fixed !important; min-height:100vh !important;}
      // ${scope} ${S.edition}{background:url('${this.asset(I.edition_bg)}') center/cover no-repeat fixed !important; }
      ${scope} ${S.create}, ${scope} ${S.character}, ${scope} ${S.waiting}, ${scope} ${S.game}, ${scope} ${S.admin}, 
      ${scope} ${S.join_page}, ${scope} ${S.combat_modal}, ${scope} ${S.endgame}{
        background:url('${this.asset(I.city_bg)}') center/cover no-repeat fixed !important;
      }
      ${scope} ${S.buttons_all}{
        background: ${C.button_bg} !important;
        border: 3px solid ${C.button_border} !important;
        color: ${C.button_text} !important;
        transition: filter .15s ease, transform .05s ease !important;
      }
      ${scope} ${S.buttons_all}:hover{
        filter: brightness(0.9) !important;
      }
      ${scope} ${S.buttons_all}:active{
        filter: brightness(0.9) !important;
        transform: translateY(1px) !important;
      }
      ${scope} ${S.buttons_all}.selected{
        filter: brightness(0.7) !important;
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

      ${scope} ${S.game_map}, ${scope} ${S.game_code}{
        background:linear-gradient(135deg, ${C.map_grad_from} 30%, ${C.map_grad_to} 100%) !important;
      }

      /* --- Styles de surbrillance des cases de la carte (mouvements possibles) --- */
      ${scope} .map-cell.highlight::before {
        background-color: rgba(8, 112, 147, 0.35) !important;
        outline: 2px solid rgba(8, 112, 147, 0.7) !important;
      }

      ${scope} .map-cell.preview-highlight::before {
        background-image: linear-gradient(
          45deg,
          rgba(8, 112, 147, 0.5) 25%,
          transparent 25%,
          transparent 50%,
          rgba(8, 112, 147, 0.5) 50%,
          rgba(8, 112, 147, 0.5) 75%,
          transparent 75%,
          transparent
        ) !important;
        background-color: rgba(8, 112, 147, 0.25) !important;
        outline: 2px solid rgba(8, 112, 147, 0.7) !important;
      }

      ${scope} ${S.info_item}, ${scope} ${S.inventory_slot}{
        background:${C.info_item_bg} !important;
      }
      
      ${scope} ${S.stat_label}, ${scope} ${S.info_label}, ${scope} ${S.status_label}, ${scope} ${S.form_label}, ${scope} ${S.char_counter}{
        color: ${C.stat_label_text} !important;
      }

      ${scope} .modify-button, ${scope} .delete-button, ${scope} .save-button, ${scope} .cancel-button, ${scope} .logout-button, ${scope} .toggle-theme-btn{
        background: ${C.button_bg} !important;
        border: 3px solid ${C.button_border} !important;
        color: ${C.button_text} !important;
        transition: filter .15s ease, transform .05s ease !important;
      }
      ${scope} .modify-button:hover, ${scope} .delete-button:hover, ${scope} .save-button:hover, ${scope} .cancel-button:hover, ${scope} .logout-button:hover, ${scope} .toggle-theme-btn:hover{
        filter: brightness(0.90) !important; 
      }
      ${scope} .modify-button:active, ${scope} .delete-button:active, ${scope} .save-button:active, ${scope} .cancel-button:active, ${scope} .logout-button:active, ${scope} .toggle-theme-btn:active{
        filter: brightness(0.90) !important;
        transform: translateY(1px) !important;
      }
      ${scope} .toggle-theme-btn .material-icons{
        color: ${C.button_text} !important;
      }

      ${scope} ${S.form_input}{
        background:${C.input_bg} !important;
        color: ${C.button_text} !important; 
        border: 2px solid ${C.modal_border} !important;
        outline: none !important;
      }
      ${scope} ${S.form_input}:focus{
        border: 2px solid ${C.input_border_focus} !important; 
      }

      /* --- Styles Modal Compte / Overlay --- */
      ${scope} ${S.modal_overlay}{
        background:${C.modal_overlay_bg} !important;
      }
      
      ${scope} ${S.stat_label}, ${scope} ${S.info_label}, ${scope} ${S.status_label}{
        color: ${C.stat_label_text} !important; /* Couleur foncée pour tous les labels */
      }

      /* --- Styles Formulaires (pour Edit Mode) --- */
      ${scope} ${S.form_input}{
        background:${C.input_bg} !important;
        color: ${C.button_text} !important; 
        border: 2px solid ${C.modal_border} !important;
        outline: none !important;
      }
      ${scope} ${S.form_input}:focus{
        border: 2px solid ${C.input_border_focus} !important; 
      }
      
      /* --- Styles Modal Compte / Overlay --- */
      ${scope} ${S.modal_overlay}{
        background:${C.modal_overlay_bg} !important;
      }
      ${scope} ${S.account_card}{
        background:${C.modal_bg} !important;
        border: 4px solid ${C.friends_border_accent} !important;
        color: ${C.button_text} !important; 
      }
      ${scope} ${S.account_card} h2, ${scope} ${S.account_card} h3{
        color: ${C.button_text} !important; 
      }
      ${scope} ${S.account_card} ${S.info_label}, ${scope} ${S.account_card} ${S.info_value}, ${scope} ${S.account_card} ${S.stat_label}, ${scope} ${
          S.account_card
      } .stat-value, ${scope} ${S.account_card} .account-title, ${scope} ${S.account_card} .stats-title, ${scope} ${
          S.account_card
      } .username-with-level, ${scope} ${S.account_card} .email-section{
        color: ${C.button_text} !important; 
      }
      ${scope} ${S.account_card} span:not(${S.buttons_all} *):not(${S.buttons_all}), ${scope} ${S.account_card} div:not(${S.buttons_all} *):not(${
          S.buttons_all
      }), ${scope} ${S.account_card} h2, ${scope} ${S.account_card} h3 {
        color: ${C.button_text} !important; 
      }
      ${scope} ${S.account_card} .status-value.online{
        color: ${C.status_online} !important;
        font-weight: bold !important;
      }
      
      ${scope} ${S.stat_item}{
        background: ${C.player_stats_bg} !important;
        border: 1px solid ${C.player_stats_border} !important;
      }

      /* --- Styles Modal Amis (Correction Bordure/Onglet/Texte) --- */
      ${scope} ${S.friends_container}{
        background:${C.modal_bg} !important;
        border: 4px solid ${C.friends_border_accent} !important; /* Bordure bleue accentuée */
      }

      /* --- Onglets et Espacement (Correction du gap) --- */
      ${scope} .tabs-container{
        display: flex !important;
        gap: 0px !important; /* Supprime l'espace entre les onglets */
      }
      ${scope} ${S.tab_button}{
        background:${C.tab_button_bg} !important;
        color: ${C.button_text} !important;
        border: 2px solid ${C.button_border} !important;
      }
      ${scope} ${S.tab_button}.active{
        background:${C.tab_button_active_bg} !important;
        border-color: ${C.friends_border_accent} !important; /* Bordure bleue accentuée */
      }
      ${scope} ${S.tab_button} ${S.notification_badge}{
        background:${C.notification_bg} !important;
        color: ${C.button_text} !important;
      }

      /* --- Champs de Recherche et Items Utilisateurs --- */
      ${scope} ${S.search_input}{
        background:${C.input_bg} !important;
        color: ${C.button_text} !important;
        border: 2px solid ${C.button_border} !important;
      }
      ${scope} ${S.search_input}:focus{
        border: 2px solid ${C.input_border_focus} !important;
      }
      
      ${scope} ${S.section_header} h4{
        color: ${C.section_header_text} !important;
      }
      ${scope} ${S.user_item}, ${scope} ${S.request_item}{
        background-color:${C.user_item_bg} !important;
        color: ${C.button_text} !important; 
      }
      
      /* Préserver les bannières dans la liste d'amis */
      ${scope} ${S.user_item}.has-banner, ${scope} ${S.request_item}.has-banner {
        background-color: transparent !important;
      }
      
      ${scope} ${S.user_item}.has-banner .user-name,
      ${scope} ${S.user_item}.has-banner .user-status,
      ${scope} ${S.user_item}.has-banner .user-details span {
        color: white !important;
        text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8), -1px -1px 2px rgba(0, 0, 0, 0.8) !important;
      }

      ${scope} ${S.request_item}:hover{
        border: 2px solid ${C.friends_border_accent} !important;
      }

      ${scope} .user-details .user-name, ${scope} .request-details .request-name {
        color: ${C.button_text} !important; 
      }

      ${scope} .user-details .pending-status{
        color: ${C.friends_border_accent} !important;
      }

      /* --- Statut --- */
      ${scope} .user-status.online{
        color: ${C.status_online} !important;
      }
      ${scope} status-value.user-status.offline{
        color: ${C.status_neutral} !important; 
      }
      ${scope} .user-status.away{
        color: ${C.notification_bg} !important; 
      }

      /* --- Styles Modal Boutique --- */
      ${scope} ${S.shop_overlay}{
        background:${C.modal_overlay_bg} !important;
      }
      ${scope} ${S.shop_container}{
        background:${C.modal_bg} !important;
        border: 4px solid ${C.friends_border_accent} !important;
        color: ${C.button_text} !important; /* Texte général en noir */
      }
      ${scope} ${S.shop_header}{
        background:${C.shop_header_bg} !important;
        border-bottom: 2px solid ${C.friends_border_accent} !important;
      }
      
      ${scope} ${S.shop_title} {
        background: none !important;
        -webkit-background-clip: unset !important;
        -webkit-text-fill-color: ${C.friends_border_accent} !important;
        color: ${C.friends_border_accent} !important; 
      }

      /* --- Barre Latérale Catégories --- */
      ${scope} ${S.category_sidebar}{
        background:${C.shop_sidebar_bg} !important;
        border-right: 1px solid ${C.modal_border} !important;
      }

       ${scope} ${S.category_btn}{
        color: ${C.buy_btn_text} !important;
        border: 2px solid transparent !important; /* BORDURE PAR DÉFAUT EN TRANSPARENT (pas de contour) */
        transition: background 0.1s ease, border-color 0.1s ease, transform 0.05s ease !important;
      }
      
      ${scope} ${S.category_btn}.active{
        background:${C.friends_border_accent} !important;
        color: ${C.buy_btn_text} !important; /* Texte actif en Bleu */
        border: 2px solid ${C.friends_border_accent} !important; /* Bordure active en Bleu (CORRIGÉ) */
      }
      
      ${scope} ${S.category_btn}:hover:not(.active){
        border: 2px solid ${C.friends_border_accent} !important; /* Bordure Hover en Bleu */
      }
      
      ${scope} ${S.sidebar_title}{
        color: ${C.shop_title_text} !important;
      }

      ${scope} ${S.shop_container} *::-webkit-scrollbar,
      ${scope} ${S.items_area} *::-webkit-scrollbar{
        width: 10px !important;
        height: 10px !important;
      }
      ${scope} ${S.shop_container} *::-webkit-scrollbar-thumb,
      ${scope} ${S.items_area} *::-webkit-scrollbar-thumb{
        background-color: ${C.friends_border_accent} !important;
        border-radius: 5px !important;
      }
      ${scope} ${S.shop_container} *::-webkit-scrollbar-track,
      ${scope} ${S.items_area} *::-webkit-scrollbar-track{
        background: ${C.modal_bg} !important;
        border-radius: 5px !important;
      }

      ${scope} ${S.unequip_btn}{
        background:${C.friends_border_accent} !important;
        color: ${C.buy_btn_text} !important;
      }
      
      /* --- Zone d'Articles --- */
      ${scope} ${S.category_header}{
        border-bottom: 1px solid ${C.modal_border} !important;
      }
      ${scope} ${S.category_title}{
        color: ${C.friends_border_accent} !important;
      }
      ${scope} ${S.item_card}{
        background:${C.item_card_bg} !important;
        border: 2px solid ${C.modal_border} !important;
        color: ${C.friends_border_accent} !important;
      }
      ${scope} ${S.item_card}.owned{
        background:${C.item_card_owned_bg} !important;
      }
      ${scope} ${S.item_card}.equipped{
        background:${C.item_card_equipped_bg} !important;
        border: 2px solid ${C.equipped_badge_bg} !important;
      }
      ${scope} ${S.item_name}{
        color: ${C.shop_title_text} !important;
        text-shadow: 1px 1px 1px rgba(0, 0, 0, 0.8) !important;

      }
      ${scope} ${S.item_card}:hover{
        border-color: ${C.friends_border_accent} !important; /* Bordure de la carte en BLEU */
      }

      ${scope} ${S.item_card}::before{
        background: linear-gradient(90deg, transparent, rgba(8, 112, 147, 0.2), transparent) !important;
      }

      ${scope} ${S.item_image}:hover{
        border-color: ${C.friends_border_accent} !important;
      }
      
      /* --- Badges et Prix --- */
      ${scope} ${S.equipped_badge}{
        background:${C.equipped_badge_bg} !important;
        color: ${C.buy_btn_text} !important;
      }
      ${scope} ${S.owned_badge}{
        background:${C.owned_badge_bg} !important;
        color: ${C.buy_btn_text} !important;
      }
      ${scope} ${S.item_price}{
        color: ${C.friends_border_accent} !important; /* Prix en bleu */
      }
    
      /* --- Tooltip Info --- */
      ${scope} ${S.info_icon_container} .info-icon{
        color: ${C.shop_title_text} !important;
      }
      ${scope} ${S.custom_tooltip}{
        background:${C.modal_bg} !important;
        border: 2px solid ${C.modal_border} !important;
        color: ${C.button_text} !important;
      }
      ${scope} .tooltip-header{
        color: ${C.friends_border_accent} !important;
        border-bottom: 1px solid ${C.modal_border} !important;
      }
      ${scope} .tooltip-content{
        color: ${C.shop_title_text} !important;
        border-bottom: 1px solid ${C.modal_border} !important;
      }
      
      /* --- No Items Message --- */
      ${scope} ${S.no_items} h3, ${scope} ${S.no_items} p{
        color: ${C.button_text} !important;
      }

      ${scope} ${S.create} .header h2, ${scope} ${S.create} .filters-label{
        color: ${C.button_text} !important; /* Titre et Label en Noir */
      }

      /* --- Bouton de Filtre survolé et Actif (Accentuation Bleue) --- */
      ${scope} ${S.filters_btn}:hover:not(.is-active), ${scope} ${S.order_btn}:hover{
        border-color: ${C.friends_border_accent} !important;
        box-shadow: 0 0 10px rgba(8, 112, 147, 0.5);
      }
      ${scope} ${S.filters_row} ${S.filters_btn}.is-active, ${scope} ${S.order_btn}.is-active{
        background: ${C.friends_border_accent} !important; /* Bouton sélectionné en BLEU (Forcé) */
        border-color: ${C.friends_border_accent} !important; /* Bordure en BLEU (Forcé) */
        color: white !important; /* Texte en Blanc pour le contraste (Forcé) */
        
        /* Supprime l'outline/box-shadow gris du CSS local et applique le halo bleu */
        outline: none !important; 
        box-shadow: 0 0 10px rgba(8, 112, 147, 0.5) !important;
      }

      /* --- Cartes de Carte (Map Cards) --- */
      ${scope} ${S.map_card}{
        background: ${C.map_card_to} !important;
        filter: brightness(1.1); 
        transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
      }
      
      /* --- Texte dans la Carte (Nom et Mode) --- */
      ${scope} ${S.map_card} ${S.map_name}, ${scope} ${S.map_card} ${S.map_mode}{
        color: ${C.button_text} !important; /* Texte en Noir/Gris foncé */
      }

      /* --- Compteur de joueurs (Barre en haut de la carte) --- */
      ${scope} ${S.map_card} .player-count-bar{
        background: ${C.input_bg} !important; /* Barre en BLEU */
        color: ${C.button_text} !important;
      }
    
      ${scope} ${S.game_options_container}{
        background: ${C.modal_bg} !important; 
        border: 4px solid ${C.friends_border_accent} !important; 
        color: ${C.button_text} !important;
        position: relative !important;
      }
      
      /* --- Titre principal et Nom de la carte --- */
      ${scope} ${S.game_options_container} ${S.modal_title_text}{ 
        color: ${C.modal_border} !important; 
      }

      ${scope} ${S.game_options_container} ${S.map_name_text} {
        color: ${C.map_grad_from} !important; 
      }

      ${scope} ${S.game_options_container} .button-group .next-button {
        background: ${C.friends_border_accent} !important;
        color: white !important; 
      }

      /* --- Carte des Options (Blocs : Elimination, Frais, etc.) --- */
      ${scope} ${S.option_card}{
        background: ${C.button_bg} !important; 
        border: 2px solid ${C.button_border} !important;
        box-shadow: 2px 2px 5px rgba(0, 0, 0, 0.2); 
      }

      ${scope} ${S.option_card}:hover{
        border-color: ${C.friends_border_accent} !important; 
        box-shadow: 0 0 8px rgba(8, 112, 147, 0.5);
      }
      
      /* --- Labels des options (Checkbox et Frais d'entrée) --- */
      ${scope} ${S.option_card} ${S.checkbox_label}, 
      ${scope} ${S.option_card} ${S.fee_label}{
        color: ${C.button_text} !important;
      }

      /* --- Descriptions des options --- */
      ${scope} ${S.option_card} ${S.option_description}{
        color: ${C.button_text} !important; 
        opacity: 0.7;
      }

      /* --- Frais d'entrée / Input --- */
      ${scope} ${S.fee_input}{
        background: white !important; 
        border: 2px solid ${C.friends_border_accent} !important; 
        color: ${C.button_text} !important; 
      }
      ${scope} ${S.fee_input}.invalid{
        border-color: red !important;
      }
      ${scope} ${S.fee_unit}, ${scope} .error-text{
        color: ${C.button_text} !important;
      }
      
      /* --- Checkboxes (Pour la couleur du texte actif/coché) --- */
      /* Note : Cible la couleur du label quand le checkbox est coché */
      ${scope} .custom-checkbox:checked + ${S.checkbox_label}{
        color: ${C.friends_border_accent} !important;
      }
      ${scope} ${S.game_options_container} .custom-checkbox:checked{
        accent-color: ${C.friends_border_accent} !important; 
        box-shadow: 0 0 5px ${C.friends_border_accent} inset !important;
      }
      
      /* --- Custom Alert Overlay (Alerte d'erreur) --- */
      ${scope} .custom-alert-overlay .custom-alert{
        background: ${C.modal_bg} !important;
        border: 4px solid ${C.friends_border_accent} !important;
        box-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
      }
      ${scope} .custom-alert-overlay .alert-title{
        color: ${C.modal_border} !important;
      }
      ${scope} .custom-alert-overlay .alert-message{
        color: ${C.filter_btn_bg} !important;
      }
      ${scope} .custom-alert-overlay .alert-button{
        /* Réutilise le style des action buttons */
        background: ${C.friends_border_accent} !important;
        border: 3px solid ${C.riends_border_accent} !important;
        color: white !important;
      }
      ${scope} .custom-alert-overlay .alert-button:hover{
        background: ${C.map_grad_from} !important;
        border-color: ${C.friends_border_accent} !important;
        box-shadow: 0 0 8px rgba(8, 112, 147, 0.5);
      }

      /* --- Styles Page de Sélection de Personnage (CHOISIS TON AVATAR) --- */
      
      ${scope} .selected-character h1 {
        color: ${C.button_text} !important; /* Texte noir */
      }

      /* --- Section des Statistiques (Côté Gauche) --- */
      ${scope} ${S.player_stats_section}{
        background: ${C.button_bg} !important; /* Fond gris clair */
        border: 4px solid ${C.button_border} !important;
        color: ${C.button_text} !important; /* Texte général noir */
        padding: 15px;
      }

      /* --- Labels des Stats (Vie, Rapidité, etc.) --- */
      ${scope} ${S.stat_label}, ${scope} ${S.bonus_text} label{
        color: ${C.button_text} !important; /* Texte noir */
      }
      ${scope} .hover-explanation span {
        color: ${C.button_bg} !important; /* Texte noir */
      }


      /* --- Barre de progression des Stats (Vie, Rapidité, etc.) --- */
      /* Le fond de la barre est généralement sombre, nous stylons uniquement le remplissage */
      ${scope} .stat-bar{
        background-color: ${C.map_grad_from} !important; 
        border: 2px solid ${C.button_border} !important; /* Bordure gris neutre/foncé */
      }
      
      /* --- Remplissage de la barre --- */
      ${scope} ${S.stat_bar_fill}{
        background-color: ${C.friends_border_accent} !important; /* Remplissage en Bleu accentué */
      }


      /* --- Boutons de Bonus (Vie/Rapidité) & Dé (Attaque/Défense) --- */
      ${scope} ${S.bonus_button}, ${scope} ${S.dice_button}{
        background: ${C.button_bg} !important;
        border: 3px solid ${C.button_border} !important;
        color: ${C.button_text} !important;
        transition: all 0.2s ease;
      }

      /* --- Boutons Bonus/Dé : Etat Survol --- */
      ${scope} ${S.bonus_button}:hover, ${scope} ${S.dice_button}:hover{
        border-color: ${C.friends_border_accent} !important; /* Bordure Bleue */
      }
      
      /* --- Boutons Bonus/Dé : Etat Sélectionné/Actif (Devient PLEIN BLEU) --- */
      ${scope} ${S.bonus_button}.selected, ${scope} ${S.dice_button}.selected{
        background-color: ${C.friends_border_accent} !important; /* Force le fond bleu */
        border-color: ${C.friends_border_accent} !important;
        color: white !important; /* Texte Blanc sur fond bleu */
        box-shadow: 0 0 8px rgba(8, 112, 147, 0.5);
      }

      /* --- Liste des Avatars (Character List) --- */
      ${scope} .character-list-section{
        background: ${C.modal_bg} !important;
        border: 4px solid ${C.button_border} !important;
      }

      /* --- Boîte d'Avatar : État Sélectionné (Devient PLEIN BLEU) --- */
      ${scope} ${S.character_box}.selected-character{
        /* Fond de la boîte sélectionnée devient PLEIN BLEU (écraser le background-color: #f39c12) */
        background-color: ${C.friends_border_accent} !important; 
        border: 2px solid ${C.friends_border_accent} !important;
        box-shadow: 0px 0px 20px 5px rgba(8, 112, 147, 0.7) !important;
      }

      /* --- Boîte d'Avatar (Chaque image dans la liste) --- */
      ${scope} ${S.character_box}{
        background: ${C.map_grad_from} !important; /* Fond gris foncé pour chaque boîte */
        border: 2px solid ${C.friends_border_accent} !important;
      }
      
      /* --- Boîte d'Avatar : Etat Survol et Sélectionné --- */
      ${scope} ${S.character_box}:hover{
        transform: scale(1.05);
        border-color: ${C.friends_border_accent} !important;
        box-shadow: 0 0 8px rgba(8, 112, 147, 0.5) !important;
      }

      ${scope} ${S.character_box}:not(.unavailable-character):hover{
        transform: scale(1.1) !important; 
        border: 2px solid ${C.friends_border_accent} !important;
        box-shadow: 0 0 20px 5px rgba(8, 112, 147, 0.7) !important; 
      }

      ${scope} ${S.character_box}.unavailable-character{
        opacity : 0.9 !important; 
      }
     
      ${scope} .character-box.locked-character:hover{
        transform: none !important; /* Annule la mise à l'échelle (zoom) au survol */
        box-shadow: none !important; /* Annule l'effet d'ombre */
        border-color: #666 !important; /* Maintient la bordure grise/neutre (tel que défini dans votre CSS par défaut) */
        opacity: 0.4 !important; /* Maintient l'opacité réduite */
      }
      
      /* --- Messages d'erreur --- */
      ${scope} ${S.error_message_char}{
        color: #e74c3c !important; /* Texte d'erreur en Rouge */
      }

      ${scope} .character-list::-webkit-scrollbar-thumb{
        background: ${C.friends_border_accent} !important; /* Bleu pour la glissière */
        border-radius: 4px !important; 
      }
      
      /* La glissière au survol */
      ${scope} .character-list::-webkit-scrollbar-thumb:hover{
        background: ${C.map_grad_from} !important; /* Gris foncé au survol */
      }

      /* La piste (le "track") */
      ${scope} .character-list::-webkit-scrollbar-track{
        background: ${C.modal_bg} !important; /* Fond sombre pour la piste */
        border-radius: 4px !important;
      }
      
      /* La barre de défilement elle-même (sa largeur) */
      ${scope} .character-list::-webkit-scrollbar {
        width: 8px !important; /* Garder la largeur par défaut, mais avec !important */
      }

      /* --- Styles Page Salle d'Attente (Waiting Room) --- */
      
      /* --- Conteneur principal du Joueur (Haut Gauche) - enfant direct de waiting-room-container --- */
      ${scope} ${S.waiting} > .player {
        background-color: ${C.button_bg} !important; /* Fond gris clair */
        border: 4px solid ${C.button_border} !important;
        color: ${C.button_text} !important;
      }
      
      /* Style pour les .player dans .players-list sans bannière */
      ${scope} ${S.players_list} .player:not(.has-banner) {
        background-color: ${C.button_bg} !important;
      }
      
      /* Nom du joueur en couleur de texte du thème */
      ${scope} .player-name h1{
        color: ${C.button_text} !important;
      }

      /* --- Avatar du Joueur Local (Haut Gauche) : Ombre Bleue --- */
      ${scope} .waiting-avatar-container img{
        border: 3px solid ${C.friends_border_accent} !important; 
        box-shadow: 0 0 15px ${C.friends_border_accent} !important;      
      }
      
      /* Styles spécifiques des colonnes Code et Carte (Doivent avoir 100% de la hauteur du parent) */
      ${scope} .game-code, ${scope} .game-map, ${scope} .entry-fee {
        background: ${C.button_bg} !important; /* Fond gris clair */
        color: ${C.button_text} !important; 
        
        border-top: 4px solid ${C.friends_border_accent} !important;
        border-bottom: 4px solid ${C.friends_border_accent} !important;
      }

      ${scope} .game-code {
        border-left: 4px solid ${C.friends_border_accent} !important;
        border-right: 2px solid ${C.friends_border_accent} !important;
      }

      ${scope} .game-map {
        border-right: 4px solid ${C.friends_border_accent} !important;
        border-left: 2px solid ${C.friends_border_accent} !important;
      }

      /* Styles de Frais d'entrée */
      ${scope} .entry-fee {
        /* Si l'élément Frais d'entrée existe, il doit utiliser ses propres couleurs */
        background: #f1c40f !important; /* Jaune standard */
        color: ${C.button_text} !important; 
        border-right: 4px solid #f39c12 !important;
        border-left: 2px solid #f39c12 !important;
        border-bottom: 4px solid #f39c12 !important;
        box-shadow: 0 0 10px rgba(243, 156, 18, 0.5) !important;
      }
      
      /* Titres et valeurs */
      ${scope} .game-details p{
        color: ${C.button_text} !important;
      }
      ${scope} .game-details h1{
        color: ${C.friends_border_accent} !important;
      }
      ${scope} .entry-fee p, ${scope} .entry-fee h1 {
        color: ${C.button_text} !important;
      }

      /* --- Styles Composant Challenge (Waiting Room) --- */
      ${scope} .challenge-container {
        color: ${C.button_text} !important;
      }

      ${scope} .challenge-full {
        background: rgba(255, 255, 255, 0.9) !important;
        border: 3px solid ${C.friends_border_accent} !important;
        box-shadow:
          0 0 10px rgba(8, 112, 147, 0.4),
          0 0 20px rgba(8, 112, 147, 0.2) !important;
      }

      ${scope} .challenge-header .challenge-title {
        color: ${C.friends_border_accent} !important;
        text-shadow: none !important;
      }

      ${scope} .challenge-header .info-icon {
        border-color: ${C.friends_border_accent} !important;
        background: rgba(8, 112, 147, 0.15) !important;
      }

      ${scope} .challenge-header .info-icon:hover {
        background: rgba(8, 112, 147, 0.3) !important;
        border-color: ${C.friends_border_accent} !important;
      }

      ${scope} .challenge-header .info-icon span {
        color: ${C.friends_border_accent} !important;
      }

      ${scope} .challenge-header .info-tooltip {
        background: rgba(255, 255, 255, 0.98) !important;
        border: 2px solid ${C.friends_border_accent} !important;
        color: ${C.button_text} !important;
      }

      ${scope} .challenge-header .info-tooltip::after {
        border-top-color: ${C.friends_border_accent} !important;
      }

      ${scope} .challenge-header .challenge-reward {
        background: rgba(8, 112, 147, 0.15) !important;
        border: 2px solid ${C.friends_border_accent} !important;
      }

      ${scope} .challenge-header .challenge-reward .reward-amount {
        color: ${C.friends_border_accent} !important;
      }

      ${scope} .challenge-description {
        color: ${C.button_text} !important;
      }

      ${scope} .progress-bar-container {
        background: rgba(0, 0, 0, 0.1) !important;
        border: 2px solid ${C.button_border} !important;
      }

      ${scope} .progress-bar {
        background: linear-gradient(90deg, ${C.friends_border_accent} 0%, #3498db 50%, #5dade2 100%) !important;
      }

      ${scope} .progress-text {
        color: ${C.friends_border_accent} !important;
        text-shadow: none !important;
      }

      ${scope} .completion-badge {
        color: #1D8348 !important;
        background: rgba(29, 131, 72, 0.15) !important;
        border: 2px solid #1D8348 !important;
      }

      ${scope} .challenge-container.completed .challenge-full {
        border-color: #1D8348 !important;
        box-shadow:
          0 0 15px rgba(29, 131, 72, 0.4),
          0 0 30px rgba(29, 131, 72, 0.2) !important;
      }

      ${scope} .challenge-container.completed .challenge-title {
        color: #1D8348 !important;
      }

      ${scope} .challenge-container.completed .progress-bar {
        background: linear-gradient(90deg, #1D8348 0%, #27ae60 50%, #2ecc71 100%) !important;
      }

      /* --- Section Liste des Joueurs / Conteneur principal --- */
      ${scope} ${S.players_list}{
        /* Couleurs demandées */
        background-color: white !important; /* Fond Blanc */
        border: 4px solid ${C.friends_border_accent} !important;
      }
      
      /* Préserver les bannières dans la liste des joueurs */
      ${scope} ${S.players_list} .player.has-banner {
        background-color: transparent !important;
      }
      
      ${scope} ${S.players_list} .player.has-banner .player-name {
        color: white !important;
        text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8), -1px -1px 2px rgba(0, 0, 0, 0.8) !important;
      }
      
      ${scope} ${S.players_list} .player.has-banner .player-content {
        color: white !important;
      }

      ${scope} .player .player-name, ${scope} .game-status h2{
        color:${C.button_text} !important;
      }
      
      /* --- Statut d'attente (En attente d'autres joueurs...) --- */
      ${scope} .player-waiting h2, ${scope} .player-waiting h1, ${scope} .host-waiting h1{
        color: ${C.friends_border_accent} !important; /* Texte d'attente en Noir/Gris foncé */
      }
      
      /* --- Message d'erreur/verrouillage de la salle pour commencer (Reste en Rouge) --- */
      ${scope} .player-waiting h2:nth-child(2), ${scope} .host-waiting h3{
        color: ${C.friends_border_accent} !important; 
      }

      
      /* --- Animation d'engrenage --- */
      ${scope} ${S.gear_animation}{
        filter: brightness(1.2); 
        color: ${C.friends_border_accent} !important; 
      }

      ${scope} .profile-modal .modal { 
        background-color: white !important; /* Bleu */
        border: 4px solid ${C.button_border} !important; /* Bordure plus douce */
        color: white !important; /* Texte/Symbole + en noir/sombre */
      }
      /* --- Styles Modal Profil du Joueur Virtuel (Profile Modal) --- */
            
      /* --- Conteneur principal (Fond Blanc, AUCUNE Bordure) --- */
      ${scope} ${S.profile_modal_container} {
        background: white !important;
        color: ${C.button_text} !important;
        border-radius: 8px !important;
        padding: 5px !important;
      }
      
      /* --- Titre du Modal --- */
      ${scope} ${S.modal_title}, ${S.close_button}{
        color: ${C.button_text} !important;
      }

        ${scope} .players-list .add-player-btn { 
          background: ${C.friends_border_accent} !important; /* Bleu */
          border: 3px solid ${C.button_border} !important; /* Bordure plus douce */
          color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
          transition: all 0.2s ease;
        }

                /* --- Bleu sur le host player dans la liste (glow effect) --- */
        ${scope} ${S.players_list} .player:first-child {
            border-color: ${C.friends_border_accent} !important;
            box-shadow:
                0 0 15px rgba(8, 112, 147, 0.6) !important,
                0 0 30px rgba(8, 112, 147, 0.5) !important,
                0 0 45px rgba(8, 112, 147, 0.4) !important,
                0 0 60px rgba(8, 112, 147, 0.3) !important;
        }

        /* --- Animation glow en bleu --- */
        ${scope} @keyframes glowing {
            0% {
                box-shadow:
                    0 0 2px rgba(8, 112, 147, 0.6),
                    0 0 4px rgba(8, 112, 147, 0.5),
                    0 0 6px rgba(8, 112, 147, 0.4),
                    0 0 8px rgba(8, 112, 147, 0.3);
            }
            50% {
                box-shadow:
                    0 0 4px rgba(8, 112, 147, 0.8),
                    0 0 8px rgba(8, 112, 147, 0.7),
                    0 0 12px rgba(8, 112, 147, 0.6),
                    0 0 16px rgba(8, 112, 147, 0.5);
            }
            100% {
                box-shadow:
                    0 0 2px rgba(8, 112, 147, 0.6),
                    0 0 4px rgba(8, 112, 147, 0.5),
                    0 0 6px rgba(8, 112, 147, 0.4),
                    0 0 8px rgba(8, 112, 147, 0.3);
            }
        }  

      /* --- Styles Modal Invitation de Partie --- */
      
      /* --- Conteneur principal (Fond Blanc) --- */
      ${scope} ${S.game_invitation_modal}{
        background: white !important; /* Fond Blanc */
        color: ${C.button_text} !important; /* Texte par défaut en noir/gris foncé */
        border: 4px solid ${C.friends_border_accent} !important; /* Bordure bleue */
        box-shadow: 0 0 15px rgba(0, 0, 0, 0.4) !important; 
      }
      
      /* --- Titre du Modal (Bleu) --- */
      ${scope} ${S.invitation_title}{
        color: ${C.friends_border_accent} !important; /* Titre en bleu accentué */
      }

      ${scope} ${S.invitation_message} strong{
        font-weight: bold !important; /* Assure que le texte est en gras */
      }
      
      /* --- Messages de l'invitation (Texte noir/gris) --- */
      ${scope} ${S.invitation_message}, ${scope} ${S.invitation_message} strong{
        color: ${C.button_text} !important; 
      }

      /* --- Nom de la partie (Bleu) --- */
      ${scope} ${S.game_name}{
        color: ${C.friends_border_accent} !important; /* Nom de la partie en bleu accentué */
      }

      /* --- Styles Interface de Combat --- */      
      
      /* --- Boutons Attaquer/Évasion (Fond en Bleu, Texte en Blanc) --- */
      ${scope} ${S.button_container_combat} .action-button{
        background: ${C.friends_border_accent} !important; /* FOND BLEU */
        color: white !important; /* Texte en Blanc sur fond bleu */
        border: 3px solid ${C.button_border} !important; /* Bordure plus claire */
      }

      ${scope} ${S.button_container_combat} .action-button:hover:not(:disabled){
        background: #087093 !important; /* Bleu légèrement plus foncé au survol */
        color: white !important;
        box-shadow: 0px 4px 0px ${C.friends_border_accent} !important; /* L'ombre reste en BLEU */
        }
      
      /* --- Compte à rebours (Gardons le jaune) --- */
      ${scope} ${S.countdown}{
        color: #f1c40f !important; /* Jaune/Or pour le compte à rebours */
      }

      /* --- Styles Page 'Rejoins une partie!' (Force tout le texte en button_text) --- *  
      
      /* Cible le titre du Header pour s'assurer qu'il est en button_text (Noir) */
      ${scope} ${S.header_join_page} h2 {
        color: ${C.button_text} !important; 
        font-size: 20px !important; /* On conserve la taille d'origine pour ne pas surcharger */
      }
      
      /* S'assurer que le titre de section est en button_text */
      ${scope} ${S.section_header} h3{
        color: ${C.button_text} !important; 
        /* On conserve la bordure douce pour la séparation */
        border-bottom: 3px solid ${C.button_border} !important; 
      }
      
      ${scope} ${S.game_access_box} h2, 
      ${scope} ${S.game_access_box} ${S.error_message} {
        color: ${C.button_text} !important; /* Texte des titres et erreurs en Noir/Gris foncé */
      }

      /* --- Cases de Saisie du Code (Objectif : Blanc) --- */
      ${scope} ${S.code_input} {
        background-color: white !important; /* Fond Blanc */
        color: ${C.button_text} !important; /* Texte de saisie en Noir/Gris foncé */
        border: 3px solid ${C.button_border} !important; /* Bordure plus douce */
        box-shadow: none !important; /* Retirer toute ombre portée du mode sombre */
      }
      
      /* S'assurer que le focus reste clair et visible */
      ${scope} ${S.code_input}:focus {
        border: 3px solid ${C.friends_border_accent} !important; /* Bordure Bleue au focus */
      }

      /* --- Styles Carte de Prévisualisation de Partie (Correction Minimaliste) --- */
      
      /* --- Carte de Jeu (Fond et Texte) --- */
      ${scope} ${S.game_card} {
        background: ${C.map_card_to} !important; 
        color: ${C.button_text} !important; 
        border: 2px solid ${C.button_border} !important;
        box-shadow: none !important;
      }

      ${scope} .game-details .name {
        color: ${C.button_text} !important; 
      }
      
      ${scope} ${S.status_bottom_waiting} .status-label,
      ${scope} ${S.status_bottom_active} .status-label {
        color: unset !important; /* Laisse la couleur par défaut du statut pour la lisibilité */
      }

      ${scope} .map-details {
        color: ${C.button_text} !important; 
      }

      ${scope} .map-details .map-actions button{
        background: ${C.friends_border_accent} !important; /* FOND BLEU */
        color: white !important; /* Texte en Blanc sur fond bleu */
        border: 3px solid ${C.button_border} !important; /* Bordure plus claire */
      }

      ${scope} .map-details .map-actions .map-delete:hover{
        background-color: #953939 !important;
      }
      ${scope} .map-details .map-actions .edit-button:hover{
        background-color: #3b3f46 !important;
      } 
      ${scope} .map-details .map-actions .duplicate-button:hover{
          background-color: #2980b9 !important;
      }

      /* --- Styles Modal de Confirmation de Suppression --- */
      
      /* --- Conteneur du Modal (Fond Blanc/Clair et Texte) --- */
      ${scope} ${S.confirmation_modal_bg} {
        background-color: white !important; 
        color: ${C.button_text} !important; 
        border: 4px solid ${C.button_border} !important;
        box-shadow: 0 0 15px rgba(0, 0, 0, 0.5) !important;
      }
      
      /* --- Titre H2 (Confirmer la suppression) --- */
      ${scope} ${S.confirmation_modal_bg} h2 {
        color: #e74c3c !important; 
      }

      ${scope} ${S.confirmation_modal_bg} p{
        color: ${C.button_text} !important; 
      }

      ${scope} .adminPage-container .modal{
        background-color: white !important; /* Bleu */
        border: 4px solid ${C.button_border} !important; /* Bordure plus douce */
        color: white !important; /* Texte/Symbole + en noir/sombre */
        box-shadow: none !important;
    }

    ${scope} .map-creation-box {
      background: white !important;
      color: ${C.button_text} !important;
    }
    
    ${scope} .game-choices-container {
      background: white !important;
      color: ${C.button_text} !important;
    }
    
      ${scope} .to-edit-button{
        background: ${C.friends_border_accent} !important;
        border: 3px solid ${C.button_border} !important;
        color: white !important;
        transition: all 0.2s ease;
      }

      ${scope} ${S.map_button},  ${S.mode_button}{
        background: ${C.button_bg} !important;
        border: 3px solid ${C.button_border} !important;
        color: ${C.button_text} !important;
        transition: all 0.2s ease;
      }

      ${scope} .filters-btn, .order-btn {
        background: ${C.button_bg} !important;
        border: 3px solid ${C.button_border} !important;
        color: ${C.button_border} !important;
        transition: all 0.2s ease;
      }
    
      ${scope} ${S.map_button}.selected,  ${S.mode_button}.selected, .filters-btn.selected, .order-btn.selected {
        background: ${C.friends_border_accent} !important;
        border: 3px solid ${C.button_border} !important;
        color: white !important;
        transition: all 0.2s ease;
      }
      
      /* --- Conteneurs Gauche et Droite (ToolBar / Control Bar) --- */
      ${scope} .map-container {
        border: 3px solid ${C.friends_border_accent}  !important; 
      }
      ${scope} .toolbar {
        background-color: ${C.map_card_to} !important; /* Fond Gris Clair */
        color: ${C.button_text} !important; /* Texte Noir */
        border-right: 4px solid ${C.friends_border_accent} !important; /* Bordure nette */
        box-shadow: 4px 0 8px rgba(0, 0, 0, 0.1) !important;
      }
      
      ${scope} ${S.right_area} {
        background-color: ${C.map_card_to} !important; /* Fond Gris Clair */
        color: ${C.button_text} !important; /* Texte Noir */
        border-left: 4px solid ${C.friends_border_accent} !important; /* Bordure nette */
        box-shadow: -4px 0 8px rgba(0, 0, 0, 0.1) !important;
      }
      
      /* --- Barre d'outils (Toolbar) et Barre de Contrôle (Control-Bar) --- */
      /* S'assurer que les barres à l'intérieur des conteneurs héritent du style */
      ${scope} ${S.toolbar} {
        color: ${C.button_text} !important;
      }

      ${scope} ${S.control_bar} {
        color: ${C.button_text} !important;
      }
      
      /* --- Titre H2 Principal (Steam & Steel BattleGrounds) --- */
      ${scope} ${S.toolbar} h2 {
        background: none !important; /* Fond Gris Clair */
        color: ${C.button_text} !important; /* Titre principal en Bleu */
        border-bottom: 3px solid ${C.button_border} !important;
        text-shadow: none !important;
      }

      /* --- Sections Pliables (Tuiles, Objets, etc.) --- */

      ${scope} ${S.toggle_section} h3 {
        border: 3px solid ${C.button_border} !important;
        background: ${C.friends_border_accent} !important; /* Fond Gris Clair */
        color: white !important; /* Sous-titres en Bleu */
        text-shadow: none !important;
      }
      
      /* Bouton + / - pour plier les sections */
      ${scope} ${S.toggle_section} button {
        background-color: ${C.friends_border_accent} !important;
        color: white !important;
        border: 3px solid ${C.button_border} !important;
      }

      ${scope} ${S.toggle_section} button:hover{
        background-color: ${C.button_border} !important;
      }
      
      /* --- Grilles d'éléments (Tuiles, Objets) --- */

      ${scope} .tile-section, .item-section, .flag-section{
        background: white !important; /* Fond Gris Clair */
        border: 3px solid ${C.button_border} !important;
      }

      ${scope} ${S.tile_grid}, 
      ${scope} ${S.item_grid}, 
      ${scope} .starting-point-section {
        background-color: white !important; /* Fond Blanc pour la zone de sélection d'éléments */
      }

      ${scope} ${S.tile_item} img, .item {
        box-shadow: 0 0 15px ${C.friends_border_accent} !important;      
      }

      ${scope} ${S.tile_item}.selected img {
        outline: 3px solid ${C.friends_border_accent} !important;
        box-shadow: 0 0 15px ${C.friends_border_accent} !important;      
      }
      
      /* Description des tuiles */
      ${scope} ${S.tile_item} .description,
      ${scope} .item .description {
        background-color: ${C.button_bg} !important; 
        color: ${C.button_text} !important;
        border: 1px solid ${C.button_border} !important;
      }

      /* --- Section d'Information sur le jeu (Control Bar) --- */
      ${scope} ${S.control_bar} h2 {
        background: none !important; /* Fond Gris Clair */
        color: ${C.button_text} !important; /* Titre principal en Bleu */
        text-shadow: none !important;
      }

      ${scope} ${S.control_bar} h3{
        color: ${C.button_text} !important; 
        text-shadow: none !important;
      }

      ${scope} .creator-area p, .state-area p{
        color: white !important; 
      }

      /* Champs de saisie (Inputs/Textarea) */
      ${scope} ${S.control_bar} input, 
      ${scope} ${S.control_bar} textarea,
      ${scope} ${S.control_bar} select {
        background-color: white !important; /* Fond Blanc */
        color: ${C.button_text} !important;
        border: 2px solid ${C.button_border} !important;
        box-shadow: none !important;
        text-shadow: none !important;
      }
      
      ${scope} ${S.edit_button_creator} {
        background-color: ${C.friends_border_accent} !important;
        color: white !important;
        border: 3px solid ${C.button_border} !important;
      }
      
      ${scope} ${S.save_button} {
        background-color: ${C.friends_border_accent} !important; /* Vert */
        color: white !important;
        border: 3px solid ${C.button_border} !important;
      }

      ${scope} ${S.control_bar} .button-section button {
        background-color: ${C.friends_border_accent} !important; /* Gris clair */
        color: white !important;
        border: 3px solid ${C.button_border} !important;
        box-shadow: none !important;
      }
      
      ${scope} ${S.control_bar} .button-section button:hover, ${scope} ${S.edit_button_creator}:hover {
        background-color: ${C.button_border} !important;
      }

      /* Game Page */

      ${scope} .actions-info,  ${scope} .dice-info  .chosen-dice, ${scope} .inventory, ${scope} .actions p, ${scope} .action-button, ${scope} .action-bar .actions  {
        border: 2px solid ${C.friends_border_accent} !important;
        background: ${C.map_card_to} !important;
        color: ${C.button_text} !important;
      }
      ${scope} .player-container {
        border: 2px solid ${C.friends_border_accent} !important;
        background: ${C.map_card_to} !important;
      }

      ${scope}  .player-container .player {
        border: none !important;
      }

      ${scope}  .player-container .player-avatar {
        border: 2px solid ${C.friends_border_accent} !important;
      }

      ${scope} .player-infos h2, ${scope} .player-infos h3 {
        color: ${C.button_text} !important;
      }
      ${scope} .dice-info .chosen-dice p {
        color: ${C.button_text} !important;
      }

      ${scope} .inventory-container{
        border-top: 2px solid ${C.friends_border_accent} !important;
        background: ${C.map_card_to} !important;
        color: ${C.button_text} !important;
      }

      ${scope} .inventory h3{
        color: ${C.button_text} !important;
      }

      ${scope} .empty-slot{
        color: ${C.friends_border_accent} !important;
      }

      ${scope} .inventory-slot{
        border: 2px dashed ${C.friends_border_accent} !important;
      }

      ${scope} .action-button:hover {
        border: 2px solid €{C.friends_border_accent} !important;
      }
      ${scope} .action-button .tooltip {
        background-color: ${C.friends_border_accent} !important;
      }

      ${scope} .action-button .tooltip::after {
        border-color: ${C.friends_border_accent} transparent transparent transparent !important;
      }

      ${scope} .game-info-wrapper { 
        background-color: white !important; /* Bleu */
        border: 2px solid ${C.friends_border_accent} !important; /* Bordure plus douce */
        color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
      }

      ${scope} .friends-list-wrapper,  ${scope} .global-chat-wrapper{
        border: 2px solid ${C.friends_border_accent} !important; /* Bordure plus douce */
      }


      ${scope} .game-info{
        background-color: white !important; /* Bleu */
        border: 1px solid ${C.friends_border_accent} !important; /* Bordure plus douce */
        color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
      }

      ${scope} .game-info h2{ 
        color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
      }

      ${scope} .game-info .info-item{ 
        background-color: ${C.map_card_to} !important; /* Bleu */
        border: 1px solid ${C.friends_border_accent} !important; /* Bordure plus douce */
      }

      ${scope} .game-info .info-item p{ 
        color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
      }

      ${scope} .game-info .info-item span{ 
        color: ${C.friends_border_accent} !important; /* Texte/Symbole + en noir/sombre */
      }

      ${scope} .turn-indicator { 
        background-color: ${C.map_card_to} !important; /* Bleu */
        border: 4px solid ${C.friends_border_accent} !important; /* Bordure plus douce */
      }

      ${scope} .turn-indicator h3 { 
         color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
      }

      ${scope} .open-exit-confirmation-modal .modal, ${scope} .game-finished-modal .modal, ${scope} .inventory-modal, ${scope} .no-active-players-modal .modal, ${scope} .exit-modal .modal, ${scope} .levelup-modal{ 
        background-color: white !important; /* Bleu */
        border: 4px solid ${C.friends_border_accent} !important; /* Bordure plus douce */
      }

      ${scope} .open-exit-confirmation-modal .modal p, .game-finished-modal .modal p, ${scope} .no-active-players-modal p, ${scope} .exit-modal .modal p, ${scope} .levelup-modal > p{
        color: ${C.button_text} !important; /* Texte/Symbole + en noir/sombre */
      }
      
      ${scope} .levelup-modal h2{
        color: ${C.friends_border_accent} !important; /* Texte/Symbole + en noir/sombre */
      }
      
      /* --- Modal Observateur --- */

      ${scope} ${S.observation_modal_content} {
        background: ${C.map_card_to} !important; 
        border: 2px solid ${C.friends_border_accent} !important;
        color: ${C.button_text} !important;
      }
      
      ${scope} ${S.observation_modal_content} .modal-header {
        border-bottom: 1px solid ${C.button_border} !important;
      }

      ${scope} ${S.observation_modal_h2} {
        color: ${C.friends_border_accent} !important;
      }
      
      ${scope} ${S.observation_modal_close} {
        color: ${C.button_text} !important;
      }
      
      ${scope} ${S.observation_modal_close}:hover {
        color: ${C.friends_border_accent} !important;
      }

      
      /* Icône (œil) */
      ${scope} ${S.observation_modal_icon} {
        color: ${C.friends_border_accent} !important;
      }
      
      /* Message principal */
      ${scope} ${S.observation_modal_message} {
        color: ${C.button_text} !important;
      }
      
      /* Bloc d'explication (cadre intérieur) */
      ${scope} ${S.observation_modal_explanation} {
        background: ${C.button_bg} !important; 
        border-left: 4px solid ${C.friends_border_accent} !important;
      }

      ${scope} ${S.observation_modal_explanation} p {
        color: ${C.friends_border_accent} !important;
      }

      ${scope} ${S.observation_modal_explanation} ul li {
        color: ${C.button_text} !important;
      }
      
      ${scope} ${S.observation_modal_explanation_p_last} {
        color: ${C.friends_border_accent} !important; 
      }
      
      ${scope} ${S.observation_modal_explanation_li_marker} {
        color: ${C.friends_border_accent} !important; 
      }
      
      ${scope} ${S.observation_modal_confirm_button} {
        box-shadow: 0 4px 15px rgba(8, 112, 147, 0.3) !important; /* Ombre bleue */
       }
      
      ${scope} ${S.observation_modal_confirm_button}:hover{
        background: ${C.friends_border_accent} !important;
        color: white !important;
        box-shadow: 0 6px 20px rgba(8, 112, 147, 0.4) !important;
      }

      ${scope} .levelup-action button, ${scope} .exit-button-container button, ${scope} .host-waiting .button-container button, ${scope} .start-button {
        background: ${C.friends_border_accent} !important;
        color: white !important;
        border: 2px solid ${C.button_border} !important;
      }

      ${scope} .levelup-action button:hover, ${scope} .exit-button-container button:hover, ${scope} .host-waiting .button-container button:hover, ${scope} .start-button:hover {
        background-color: ${C.button_border} !important;
      }
      
      ${scope} .game-players-list {
        color: ${C.button_text} !important;
      }
      
      ${scope} ${S.player_item} {
        /* Règle 1 : Remplacer la bordure dégradée orange par le bleu */
        border: 2px solid transparent !important;
        border-image: linear-gradient(to left, ${C.friends_border_accent}, rgba(0, 0, 0, 0)) 1 !important;
        background: transparent !important;
      }

      ${scope} ${S.player_active} {
        border: none !important;
        /* Règle 1 : Remplacer le fond dégradé orange par le bleu */
        background: linear-gradient(to left, ${C.friends_border_accent} 50%, rgba(0, 0, 0, 0)) !important;
      }
      
      ${scope} ${S.player_left_separator},
      ${scope} ${S.observation_mode_separator} {
        background-color: ${C.friends_border_accent} !important;
      }

      ${scope} ${S.turn_arrow} {
        /* Règle 1 : Flèche en bleu */
        color: ${C.friends_border_accent} !important;
        /* Règle 1 : Mettre le glow en bleu */
        animation: blue_glow 1.5s infinite alternate !important; 
      }

      ${scope} @keyframes blue_glow {
        0% {
          text-shadow: 0 0 5px ${C.friends_border_accent}, 0 0 10px ${C.friends_border_accent};
        }
        100% {
          text-shadow: 0 0 20px ${C.friends_border_accent}, 0 0 30px ${C.friends_border_accent};
        }
      }
      
      ${scope} .player-info {
        /* Règle 3 : Texte par défaut en button_text (Noir/Gris) */
        color: ${C.button_text} !important;
      }
      
      /* Nom du Joueur */
      ${scope} ${S.player_name} {
        /* Règle 3 : Texte du nom en button_text */
        color: ${C.button_text} !important; 
      }
      
      /* Statut du Joueur & Victoires */
      ${scope} ${S.player_status},
      ${scope} ${S.victories} {
        /* Règle 3 : Texte en button_text */
        color: ${C.button_text} !important;
      }
      
      ${scope} .player-status::after,
      ${scope} .player-info:after,
      ${scope} .victories::after {
        /* Règle 1 : Séparateur en bleu */
        background-color: ${C.friends_border_accent} !important;
      }

      /* --- Styles Écran de Fin de Partie (.endgame-container) --- */
      
      ${scope} ${S.endgame_stats_container},
      ${scope} ${S.endgame_global_stats_container} {
        /* Règle 2 : Remplacer le fond sombre par une couleur claire avec transparence */
        background-color: rgba(255, 255, 255, 0.9) !important;
        /* Règle 1 : Remplacer la bordure orange par le bleu */
        border: 2px solid ${C.friends_border_accent} !important;
      }
      
      /* Titres H1 & Titres des stats globales */
      ${scope} ${S.endgame_h1} {
        /* Règle 3 : Texte en Noir/Gris */
        color: ${C.button_text} !important;
      }

      /* Texte des stats globales */
      ${scope} ${S.endgame_global_stats_container} p {
        /* Règle 3 : Texte en Noir/Gris */
        color: ${C.button_text} !important;
      }

      /* --- Styles Spécifiques pour les cellules des joueurs dans le tableau --- */
      
      /* Cellules de données du tableau (TD) */
      ${scope} .endgame-container table{
        background: ${C.button_bg} !important; 
      }
      
      /* Garder les bannières visibles sur les lignes */
      ${scope} .endgame-container table tr.has-banner {
        background-color: transparent !important;
      }
      
      /* Assurer que le texte reste lisible sur les bannières */
      ${scope} .endgame-container table tr.has-banner td {
        text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8), -1px -1px 2px rgba(0, 0, 0, 0.8) !important;
      }
      
      ${scope} .endgame-container table tr.has-banner .player-name {
        color: white !important;
        text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.9), -1px -1px 3px rgba(0, 0, 0, 0.9) !important;
      }
      
      ${scope} .endgame-container table tr.has-banner .cell-content {
        color: white !important;
      }
      
      ${scope} ${S.endgame_table_td} {
        /* Règle 3 : Texte en Noir/Gris */
        color: ${C.button_text} !important;
        /* Lignes de séparation */
        border-bottom: 1px solid ${C.button_border} !important;
      }

      /* Nom du joueur dans le tableau (.player-name) */
      ${scope} ${S.endgame_player_name} {
        /* Règle 3 : Texte en Noir/Gris */
        color: ${C.button_text} !important;
      }
      
      /* Lignes de tableau au survol (TR:hover) */
      ${scope} ${S.endgame_table} tr:hover {
        /* Règle 2 : Remplacer le fond sombre au survol par du gris plus clair */
        background-color: ${C.button_bg} !important;
      }

      /* Lignes de tableau avec bannière (obscurcissement) */
      ${scope} ${S.endgame_table} tr.has-banner::before {
        /* Obscurcir moins le fond clair */
        background: rgba(0, 0, 0, 0.1) !important;
      }
      ${scope} ${S.endgame_table} tr.has-banner:hover::before {
        /* Obscurcir encore moins au survol */
        background: rgba(0, 0, 0, 0.05) !important;
      }
        
      /* --- Scrollbar du tableau --- */
      ${scope} .stats-container::-webkit-scrollbar-thumb {
        /* Règle 1 : Remplacer le bleu existant par la couleur accentuée */
        background: ${C.friends_border_accent} !important; 
      }
      ${scope} .stats-container::-webkit-scrollbar-thumb:hover {
        /* Règle 1 : Remplacer le bleu existant par un bleu plus foncé */
        background: #087093 !important;
      }
      ${scope} .chat-container {
        background: white !important;
       } 
       ${scope} .chat-section {
        background: white !important;
      } 
    
    /* HEADER */
    ${scope} .chat-header {
        background: white !important;
        color: #222 !important;
        border-bottom: 2px solid ${C.friends_border_accent} !important;
    }
    
    ${scope} .toggle-icon,
    ${scope} .close-button {
        color: ${C.friends_border_accent} !important;
    }
    
    /* CHANNEL CONTROL BUTTONS */
    ${scope} .channel-controls {
        background: white !important;
        border-bottom: 1px solid ${C.friends_border_accent} !important;
    }
    
    ${scope} .channel-button {
        background: #EAF2F7 !important;
        color: #222 !important;
        border: 2px solid ${C.friends_border_accent} !important;
    }
    
    ${scope} .channel-button:hover {
        background: #d9e7f2 !important;
    }
    
    /* ACTIVE CHANNEL BAR */
    ${scope} .chat-header-info {
        background: white !important;
        border-bottom: 1px solid ${C.friends_border_accent} !important;
    }
    
    ${scope} .active-channel {
      color: ${C.friends_border_accent} !important;
      border-bottom: 2px solid ${C.friends_border_accent} !important;
    }
    
    /* CHANNEL LISTS */
    ${scope} .channel-panel {
        background: #F7FAFC !important;
        border-bottom: 1px solid ${C.friends_border_accent} !important;
    }
    
    ${scope} .channel-item {
        border-bottom: 1px solid #d0d8df !important;
    }
    
    ${scope} .channel-item:hover {
        background: #EAF2F7 !important;
    }
    
    ${scope} .channel-item.active {
        background: ${C.friends_border_accent} !important;
        color: white !important;
    }
    
    /* INPUT (search + message) */
    ${scope} .search-input,
    ${scope} #messageInput {
        background: #F2F6FA !important;
        border: 2px solid ${C.friends_border_accent} !important;
        color: #222 !important;
    }
    
    ${scope} #messageInput::placeholder {
        color: #8aa3b5 !important;
    }
    
    /* MESSAGE LIST */
    ${scope} .message-area {
        background: #F7FAFC !important;
    }
    
    ${scope} .message-item {
        background: rgba(0,0,0,0.03) !important;
        border-left: 3px solid ${C.friends_border_accent} !important;
        color: #222 !important;
    }

    ${scope} .message-text {
      color: black !important;
    }
    
    ${scope} .channel-name {
      color: black !important;
    }   
    
    ${scope} .author {
        color: ${C.friends_border_accent} !important;
    }
    
    ${scope} .timestamp {
        color: #7b8d97 !important;
    }
    
    /* AVATARS */
    ${scope} .author-avatar {
        background: #dbe7f0 !important;
        border: 2px solid ${C.friends_border_accent} !important;
    }
    
    /* STATUS BADGES */
    ${scope} .status-indicator.status-online {
        background: #2ecc71 !important;
    }
    
    ${scope} .status-indicator.status-ingame {
        background: ${C.friends_border_accent} !important;
    }
    
    ${scope} .status-indicator.status-offline {
        background: #a0b4c2 !important;
    }
    
    /* INPUT BAR AT BOTTOM */
    ${scope} .input-container {
        background: white !important;
        border-top: 2px solid ${C.friends_border_accent} !important;
    }
    
    /* SEND BUTTON */
    ${scope} .send-message-button {
        background: ${C.friends_border_accent} !important;
    }
    
    ${scope} .send-message-button:hover {
        background: #8ab8d7 !important;
    }
    




      `.trim();
        this.ensureStyle().textContent = css;
    }
}
