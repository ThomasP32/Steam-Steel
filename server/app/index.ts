import { AppModule } from '@app/app.module';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { json } from 'express';
const bootstrap = async () => {
    const app = await NestFactory.create(AppModule); // creation d'une instance de l'application
    app.use(json({ limit: '10mb' }));
    app.setGlobalPrefix('api'); // ajoute un préfixe global à toute les routes (/courses devient /api/courses)
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            forbidNonWhitelisted: true,
            transform: true,
        }),
    );
    app.enableCors();

    const config = new DocumentBuilder() // configure swagger qui genere documentation interactive de l'api
        .setTitle('Cadriciel Serveur')
        .setDescription('Serveur du projet de base pour le cours de LOG2990')
        .setVersion('1.0.0')
        .build();
    const document = SwaggerModule.createDocument(app, config); // genere le document swagger pour l'app avec les config
    SwaggerModule.setup('api/docs', app, document); // fait que lorsque taccede a /api/docs dans ton nav tu vois la documentation
    SwaggerModule.setup('', app, document); // meme chose mais a lurl racine

    const port = process.env.PORT ? Number(process.env.PORT) : 3000;
    // bind to 0.0.0.0 so the server is reachable from other machines on the network
    await app.listen(port, '0.0.0.0'); // indique ecouter un port specifique pour les requetes
};

bootstrap();
