package main

import (
	"log"
	"net/http"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
    "context"
)

func main() {
	log.Println("Starting Marketing Data Service...")

	// Database Connection
	dbUrl := os.Getenv("OPS_DATABASE_URL")
	if dbUrl == "" {
		log.Fatal("OPS_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dbUrl)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer pool.Close()

    mux := http.NewServeMux()

    mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(200)
        if _, err := w.Write([]byte("ok")); err != nil {
            log.Printf("Failed to write response: %v", err)
        }
    })

    // Placeholder for Google Ads Campaigns
    mux.HandleFunc("/api/marketing/google/campaigns", func(w http.ResponseWriter, r *http.Request) {
        // Validation would go here
        w.WriteHeader(501)
        if _, err := w.Write([]byte("not implemented")); err != nil {
            log.Printf("Failed to write response: %v", err)
        }
    })

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server listening on :%s", port)
    // Add Auth Middleware
	if err := http.ListenAndServe(":"+port, authMiddleware(mux, os.Getenv("INTERNAL_API_TOKEN"))); err != nil {
        log.Fatalf("Server failed: %v", err)
    }
}

func authMiddleware(next http.Handler, token string) http.Handler {
  return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    if r.Header.Get("x-internal-token") != token {
      http.Error(w, "unauthorized", http.StatusUnauthorized)
      return
    }
    next.ServeHTTP(w, r)
  })
}
