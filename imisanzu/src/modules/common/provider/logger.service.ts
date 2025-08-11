export class LoggerService {

    public constructor() {
        // Using console logging with OpenTelemetry auto-instrumentation
    }

    public info(message: string) {
        console.log(`[INFO] ${new Date().toISOString()} ${message}`);
    }

    public error(message: string) {
        console.error(`[ERROR] ${new Date().toISOString()} ${message}`);
    }

}
