import { ItemCategory } from './map.types';

  export type PublicChallengeView = {
    title: string;
    description: string;
    reward: number;
    progress: number;   // 0..1
    completed: boolean;
  };
  
  export enum ChallengeType {
    VISIT_TILES_25 = 'visit_tiles_25',
    DEAL_5_DAMAGE  = 'deal_5_damage',
    ESCAPE_5_ATTACKS     = 'no_hp_loss',
    OPEN_2_DOORS   = 'open_2_doors',
    COLLECT_2_ITEMS= 'collect_2_items',
  }
  
  export type ChallengeState = {
    type: ChallengeType;
    title: string;
    description: string;
    reward: number;
  
    // internal counters (server only)
    visitedTiles?: number;
    damageDealt?: number;
    attacksDodged?: number;
    doorsOpened?: number;
    itemsCollected?: number;
    collectedItems?: ItemCategory[];
  
    // derived
    progress: number;   // 0..1
    completed: boolean; // live flag (NO_HP_LOSS finalized at end)
  };
  