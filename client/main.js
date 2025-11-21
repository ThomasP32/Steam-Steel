const { app, BrowserWindow } = require('electron');

let appWindow;

function initWindow() {
    appWindow = new BrowserWindow({
        // fullscreen: true,
        height: 800,
        width: 1000,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
        },
    });

    // Electron Build Path
    const path = `file://${__dirname}/dist/client/index.html`;
    appWindow.loadURL(path);

    appWindow.setMenuBarVisibility(false);

    // Initialize the DevTools.
    // appWindow.webContents.openDevTools();

    // Gérer la fermeture de la fenêtre
    appWindow.on('close', function (event) {
        // Envoyer un événement à l'application Angular avant de fermer
        appWindow.webContents.send('app-closing');

        // Donner un peu de temps pour que la déconnexion se fasse
        setTimeout(() => {
            appWindow = null;
        }, 500);
    });

    appWindow.on('closed', function () {
        appWindow = null;
    });
}

app.on('ready', initWindow);

// Close when all windows are closed.
app.on('window-all-closed', function () {
    // On macOS specific close process
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', function () {
    if (appWindow === null) {
        initWindow();
    }
});
