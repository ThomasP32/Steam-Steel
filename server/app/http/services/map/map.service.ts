import { MapDocument } from '@app/http/model/schemas/map/map.schema';
import { Map, MapState } from '@common/map.types';
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';

@Injectable()
export class MapService {
    @InjectModel(Map.name) public mapModel: Model<MapDocument>;

    async getAllVisibleMaps(): Promise<Map[]> {
        return await this.mapModel.find({ isVisible: true }, { _id: 0, isVisible: 0, lastModified: 0 });
    }

    async getMapByName(mapName: string): Promise<Map> {
        const map = await this.mapModel.findOne({ name: mapName, isVisible: true }, { _id: 0, isVisible: 0, lastModified: 0 });
        if (!map) {
            throw new Error(`Failed to find visible map : ${mapName}`);
        }
        return map;
    }

    async getVisibleMapsForUser(userId: string): Promise<Map[]> {
        const maps = await this.mapModel.find(
            {
                isVisible: true,
                $or: [{ state: MapState.Public }, { state: MapState.Share }, { creator: userId }],
            },
            { _id: 0, isVisible: 0, lastModified: 0 },
        );

        const uniqueMaps = maps.filter((map, index, self) => index === self.findIndex((m) => m.name === map.name));

        return uniqueMaps;
    }
}
