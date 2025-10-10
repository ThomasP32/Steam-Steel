// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.

export const environment = {
    production: false,
    // During local development the dev-server proxy should forward these paths.
    // If the proxy is misconfigured or you run into ECONNREFUSED, use the full
    // backend address so the client connects directly to the server.
    serverUrl: 'http://localhost:3000/api',
    socketUrl: 'http://localhost:3000/game',
};

/*
 * For easier debugging in development mode, you can import the following file
 * to ignore zone related error stack frames such as `zone.run`, `zoneDelegate.invokeTask`.
 *
 * This import should be commented out in production mode because it will have a negative impact
 * on performance if an error is thrown.
 */
// import 'zone.js/plugins/zone-error';  // Included with Angular CLI.
