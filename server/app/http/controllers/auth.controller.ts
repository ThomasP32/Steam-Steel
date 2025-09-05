import { Body, Controller, HttpStatus, Inject, Post, Res } from '@nestjs/common';
import { ApiCreatedResponse, ApiNotFoundResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { UserService } from '../services/user.service';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
    @Inject(UserService) private readonly userService: UserService;

    @ApiCreatedResponse({
        description: 'Register a new user',
    })
    @ApiNotFoundResponse({
        description: 'Return BAD_REQUEST http status when registration fails',
    })
    @Post('register')
    async register(
        @Body('email') email: string,
        @Body('password') password: string,
        @Body('pseudonyme') pseudonyme: string,
        @Body('avatar') avatar: string,
        @Res() response: Response,
    ) {
        // Vérification des champs obligatoires
        if (!email || !password || !pseudonyme) {
            return response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: 'Email, mot de passe et pseudonyme sont obligatoires.',
            });
        }
        // Vérification du format de l'email
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: "Le format de l'email est invalide.",
            });
        }
        // Vérification unicité email et pseudonyme
        try {
            const existingEmail = await this.userService.findByEmail(email);
            if (existingEmail) {
                return response.status(HttpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Cet email est déjà utilisé.',
                });
            }
            const existingPseudo = await this.userService.findByPseudonyme(pseudonyme);
            if (existingPseudo) {
                return response.status(HttpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Ce pseudonyme est déjà utilisé.',
                });
            }
            const user = await this.userService.create(email, password, pseudonyme, avatar);
            response.status(HttpStatus.CREATED).json({ success: true, message: 'Inscription réussie !', user });
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: error.message || 'Registration failed',
                error,
            });
        }
    }

    @ApiOkResponse({
        description: 'Login user',
    })
    @ApiNotFoundResponse({
        description: 'Return UNAUTHORIZED http status when login fails',
    })
    @Post('login')
    async login(@Body('email') email: string, @Body('password') password: string, @Res() response: Response) {
        try {
            const user = await this.userService.validateUser(email, password);
            if (user) {
                response.status(HttpStatus.OK).json({ success: true, message: 'Connexion réussie !', user });
            } else {
                response.status(HttpStatus.UNAUTHORIZED).json({
                    success: false,
                    message: 'Invalid credentials',
                });
            }
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: error.message || 'Login failed',
            });
        }
    }
}
