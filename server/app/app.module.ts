import { AdminController } from '@app/http/controllers/admin/admin.controller';
import { AuthController } from '@app/http/controllers/auth.controller';
import { ChannelController } from '@app/http/controllers/channel.controller';
import { MapController } from '@app/http/controllers/map/map.controller';
import { Channel, ChannelSchema } from '@app/http/model/schemas/channel/channel.schema';
import { Map, mapSchema } from '@app/http/model/schemas/map/map.schema';
import { Message, MessageSchema } from '@app/http/model/schemas/message/message.schema';
import { User, UserSchema } from '@app/http/model/schemas/user/user.schema';
import { AdminService } from '@app/http/services/admin/admin.service';
import { ChannelService } from '@app/http/services/channel/channel.service';
import { MapService } from '@app/http/services/map/map.service';
import { UserService } from '@app/http/services/user/user.service';
import { GameCreationService } from '@app/services/game-creation/game-creation.service';
import { JournalService } from '@app/services/journal/journal.service';
import { ChatRoomGateway } from '@app/socket/game/gateways/chatroom/chatroom.gateway';
import { GameGateway } from '@app/socket/game/gateways/game-creation/game-creation.gateway';
import { Logger, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { FriendsController } from './http/controllers/friends/friends.controller';
import { ShopController } from './http/controllers/shop/shop.controller';
import { FriendsService } from './http/services/friends/friends.service';
import { ChallengeService } from './services/challenge/challenge.service';
import { ChatroomService } from './services/chatroom/chatroom.service';
import { CombatService } from './services/combat/combat.service';
import { CombatCountdownService } from './services/countdown/combat/combat-countdown.service';
import { GameCountdownService } from './services/countdown/game/game-countdown.service';
import { GameManagerService } from './services/game-manager/game-manager.service';
import { ItemsManagerService } from './services/items-manager/items-manager.service';
import { ShopService } from './services/shop/shop.service';
import { UserSocketService } from './services/user-socket/user-socket.service';
import { VirtualGameManagerService } from './services/virtual-game-manager/virtual-game-manager.service';
import { AccountGateway } from './socket/game/gateways/account/account.gateway';
import { AdminGateway } from './socket/game/gateways/admin/admin.gateway';
import { CombatGateway } from './socket/game/gateways/combat/combat.gateway';
import { FriendsGateway } from './socket/game/gateways/friends/friends.gateway';
import { GameManagerGateway } from './socket/game/gateways/game-manager/game-manager.gateway';
import { ShopGateway } from './socket/game/gateways/shop/shop.gateway';
@Module({
    // decorateur qui permet d'indique que la classe regroupe controleur, service, etc.
    imports: [
        ConfigModule.forRoot({ isGlobal: true }), // charge les configs comme .env disponible partout dans appmodule
        MongooseModule.forRootAsync({
            imports: [ConfigModule], // importe le module qui fournit configservice
            inject: [ConfigService], // injecte configservice dans usefactory
            useFactory: async (config: ConfigService) => ({
                // retourne la configuration pour mongoose
                uri: config.get<string>('DATABASE_CONNECTION_STRING'), // Loaded from .env
            }),
        }),
        MongooseModule.forFeature([
            { name: Map.name, schema: mapSchema },
            { name: User.name, schema: UserSchema },
            { name: Message.name, schema: MessageSchema },
            { name: Channel.name, schema: ChannelSchema },
        ]),
    ],
    controllers: [MapController, AdminController, AuthController, ChannelController, FriendsController, ShopController],
    providers: [
        MapService,
        AdminService,
        ChannelService,
        GameCreationService,
        GameGateway,
        Logger,
        ChatRoomGateway,
        ChatroomService,
        CombatGateway,
        CombatService,
        GameManagerGateway,
        GameManagerService,
        JournalService,
        GameCountdownService,
        CombatCountdownService,
        VirtualGameManagerService,
        ItemsManagerService,
        UserService,
        UserSocketService,
        AccountGateway,
        AdminGateway,
        FriendsService,
        FriendsGateway,
        ChallengeService,
        ShopGateway,
        ShopService,
    ],
})
export class AppModule {}
