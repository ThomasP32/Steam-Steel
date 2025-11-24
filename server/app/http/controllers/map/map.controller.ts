import { Map } from '@app/http/model/schemas/map/map.schema';
import { MapService } from '@app/http/services/map/map.service';
import { UserService } from '@app/http/services/user/user.service';
import { JWT_SECRET } from '@common/constants';
import { Controller, Get, HttpStatus, Inject, Param, Query, Res } from '@nestjs/common';
import { ApiNotFoundResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import * as jwt from 'jsonwebtoken';

@ApiTags('Map')
@Controller('map')
export class MapController {
    @Inject(MapService) private readonly mapService: MapService;
    @Inject(UserService) private readonly userService: UserService;

    @ApiOkResponse({
        description: 'Returns all maps',
        type: Map,
        isArray: true,
    })
    @ApiNotFoundResponse({
        description: 'Return NOT_FOUND http status when request fails',
    })
    @Get('/')
    async allMaps(@Res() response: Response) {
        try {
            const maps = await this.mapService.getAllVisibleMaps();
            response.status(HttpStatus.OK).json(maps);
        } catch (error) {
            response.status(HttpStatus.NOT_FOUND).send(error.message);
        }
    }

    @ApiOkResponse({
        description: 'Returns maps visible to the authenticated user (public maps + own maps)',
        type: Map,
        isArray: true,
    })
    @ApiNotFoundResponse({
        description: 'Return NOT_FOUND http status when request fails',
    })
    @Get('/user/visible')
    async getVisibleMapsForUser(@Query('token') token: string, @Res() response: Response) {
        try {
            if (!token) {
                return response.status(HttpStatus.BAD_REQUEST).json({ message: 'Token manquant' });
            }

            const decoded: any = jwt.verify(token, JWT_SECRET);
            if (!decoded || !decoded.userId) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ message: 'Token invalide' });
            }

            const user = await this.userService.findById(decoded.userId);
            if (!user) {
                return response.status(HttpStatus.NOT_FOUND).json({ message: 'Utilisateur non trouvé' });
            }

            const maps = await this.mapService.getVisibleMapsForUser(user._id.toString());
            response.status(HttpStatus.OK).json(maps);
        } catch (error) {
            if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
                response.status(HttpStatus.UNAUTHORIZED).json({ message: 'Token invalide ou expiré' });
            } else {
                response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ message: error.message });
            }
        }
    }

    @ApiOkResponse({
        description: 'Get map by name',
        type: Map,
    })
    @ApiNotFoundResponse({
        description: 'Return NOT_FOUND http status when request fails',
    })
    @Get('/:mapName')
    async getMapByName(@Param('mapName') mapName: string, @Res() response: Response) {
        try {
            const map = await this.mapService.getMapByName(mapName);
            response.status(HttpStatus.OK).json(map);
        } catch (error) {
            response.status(HttpStatus.NOT_FOUND).send(error.message);
        }
    }
}
