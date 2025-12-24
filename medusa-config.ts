import { loadEnv, defineConfig, Modules } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    }
  },
  admin: {
    path: "/app",
    backendUrl: process.env.MEDUSA_BACKEND_URL || "https://api.orgasmtoy.com",
  },
  modules: [
    {
      resolve: "@medusajs/medusa/payment",
      options: {
        providers: [
          {
            resolve: "@medusajs/payment-stripe",
            id: "stripe",
            options: {
              apiKey: process.env.STRIPE_API_KEY || "sk_test_unused",
              webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || "whsec_unused",
              // Stripe handles card payments, Apple Pay, Google Pay
              // Klarna will be added separately with direct integration
              paymentMethodTypes: [
                "card",
                "apple_pay",
                "google_pay",
              ],
            },
          },
        ],
      },
    },
    {
      resolve: "./src/modules/blog",
    },
  ],
})
