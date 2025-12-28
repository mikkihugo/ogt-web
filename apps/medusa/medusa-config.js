const { loadEnv, defineConfig } = require("@medusajs/framework/utils");

loadEnv(process.env.NODE_ENV || "development", process.cwd());

module.exports = defineConfig({
  projectConfig: {
    databaseUrl:
      process.env.DATABASE_URL ||
      "postgres://postgres:postgres@localhost:5432/medusa-db",
    http: {
      storeCors:
        process.env.STORE_CORS || "http://localhost:8000,http://localhost:3000",
      adminCors:
        process.env.ADMIN_CORS || "http://localhost:7000,http://localhost:7001",
      authCors:
        process.env.AUTH_CORS || "http://localhost:8000,http://localhost:3000",
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
  },
  admin: {
    path: "/app",
    backendUrl: process.env.MEDUSA_BACKEND_URL || "https://admin.ownorgasm.com",
    // Can disable admin for backend-only build
    disable: process.env.MEDUSA_DISABLE_ADMIN === "true",
  },
  modules: [
    // Modules commented out in TS version, preserving comments
  ],
});
