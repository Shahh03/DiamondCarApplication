import mongoose from "mongoose";
import dns from "node:dns";

// Initialize monitoring before loading the application and its dependencies.
const { Sentry, captureServerFailure } = await import("./config/sentry.js");

class Server {
  async start() {
    const [
      { default: App },
      { reportStartupHealth },
      { startBookingHoldExpiryWorker },
    ] = await Promise.all([
      import("./App.js"),
      import("./config/startupHealth.js"),
      import("./services/bookingHoldExpiry.service.js"),
    ]);

    const app = new App();
    let databaseError = null;
    try {
      dns.setServers(["8.8.8.8", "1.1.1.1"]);
      await app.connectToDatabase();
    } catch (error) {
      databaseError = error;
    }

    await reportStartupHealth();

    // MongoDB is required. Show every dependency status first, then stop
    // startup instead of accepting requests without a database connection.
    if (databaseError) throw databaseError;

    app.initializeMiddlewares();
    startBookingHoldExpiryWorker();
    app.listen();
  }
}

try {
  await new Server().start();
} catch (error) {
  captureServerFailure(error, "startup");
  console.error("Server startup failed:", error);
  await Sentry.flush(2000);
  process.exit(1);
}

