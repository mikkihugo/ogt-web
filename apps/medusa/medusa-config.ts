import { loadEnv, defineConfig } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())

export default defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL || "postgres://postgres:postgres@localhost:5432/medusa-db",
    http: {
      storeCors: process.env.STORE_CORS || "http://localhost:8000,http://localhost:3000",
      adminCors: process.env.ADMIN_CORS || "http://localhost:7000,http://localhost:7001",
      authCors: process.env.AUTH_CORS || "http://localhost:8000,http://localhost:3000",
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    }
  },
  admin: {
    path: "/app",
    backendUrl: process.env.MEDUSA_BACKEND_URL || "https://admin.ownorgasm.com",
    disable: false,
  },
  modules: [
    {
      resolve: "@medusajs/payment",
      options: {
        providers: [
          {
            resolve: "@medusajs/payment-stripe",
            id: "stripe",
            options: {
              apiKey: process.env.STRIPE_API_KEY || "sk_test_unused",
              webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || "whsec_unused",
              paymentMethodTypes: ["card", "apple_pay", "google_pay"],
            },
          },
        ],
      },
    },
    {
      resolve: "@medusajs/file-s3",
      options: {
        providers: [
          {
            resolve: "@medusajs/file-s3",
            id: "s3-minio",
            options: {
              file_url: process.env.MINIO_ENDPOINT || "http://localhost:9000",
              access_key_id: process.env.MINIO_ACCESS_KEY,
              secret_access_key: process.env.MINIO_SECRET_KEY,
              region: "us-east-1",
              bucket: "medusa-media",
              endpoint: process.env.MINIO_ENDPOINT,
              s3_force_path_style: true
            }
          }
        ]
      }
    }
  ],
})
