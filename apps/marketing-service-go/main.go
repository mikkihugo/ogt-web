package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/tax/calculation"
)

type Product struct {
	SKU  string  `json:"sku"`
	Qty  int     `json:"qty"`
	Cost float64 `json:"cost"`
}

type TaxRequest struct {
	CartTotal     int64  `json:"cart_total"`
	CustomerState string `json:"customer_state"`
}

type TaxResponse struct {
	TaxAmount int64 `json:"tax_amount"`
}

type GoogleAdsClient struct {
    CustomerID string
}

func (c *GoogleAdsClient) GetCampaignPerformance() map[string]interface{} {
    return map[string]interface{}{
        "campaign_id": "123456789",
        "clicks": 150,
        "impressions": 5000,
        "cost_micros": 25000000, // $25.00
    }
}


func main() {
	log.Println("Starting Dropship API (Unified Backend)...")

	// Database Connection
	dbUrl := os.Getenv("DATABASE_URL")
	if dbUrl == "" {
		log.Fatal("DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dbUrl)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer pool.Close()

	// Stripe Init
	stripe.Key = os.Getenv("STRIPE_API_KEY")

	// Router
	r := chi.NewRouter()

	r.Route("/api", func(r chi.Router) {
		// 1. Products Endpoint (for Refine Admin)
		r.Get("/products", func(w http.ResponseWriter, r *http.Request) {
			// Mocking DB query for now since table structure isn't confirmed
			// rows, _ := pool.Query(context.Background(), "SELECT sku, qty, cost FROM inventory")
			// defer rows.Close()

			// Return mock data for Refine demo
			items := []Product{
				{SKU: "SKU-123", Qty: 100, Cost: 25.50},
				{SKU: "SKU-456", Qty: 5, Cost: 120.00},
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(items)
		})

		// 2. Sync Trigger
		r.Post("/sync", func(w http.ResponseWriter, r *http.Request) {
			go runSync()
			w.Write([]byte("Sync job started in background"))
		})

		// 3. Tax Calculation Endpoint (for Storefront)
		r.Post("/calculate-tax", func(w http.ResponseWriter, r *http.Request) {
			var req TaxRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}

			taxAmount := calculateTax(req.CartTotal, req.CustomerState)
			
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(TaxResponse{TaxAmount: taxAmount})
		})

        // 4. Marketing Report Endpoint
        r.Get("/report", func(w http.ResponseWriter, r *http.Request) {
            adsClient := &GoogleAdsClient{CustomerID: "cust_001"}
            data := adsClient.GetCampaignPerformance()
            
            w.Header().Set("Content-Type", "application/json")
            json.NewEncoder(w).Encode(data)
        })
	})

	// Serve Static Files (Admin Panel)
	workDir, _ := os.Getwd()
	filesDir := http.Dir(workDir + "/dist") // Standard Vite output location
	FileServer(r, "/", filesDir)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server listening on :%s", port)
	http.ListenAndServe(":"+port, r)
}

func runSync() {
	log.Println("Running sync logic...")
	// Placeholder for sync logic
}

func calculateTax(cartTotal int64, customerState string) int64 {
	// Skip tax calc if key missing (dev mode)
	if stripe.Key == "" {
		log.Println("Stripe Key missing, skipping tax calc")
		return 0
	}

	params := &stripe.TaxCalculationParams{
		Currency: stripe.String(string(stripe.CurrencyUSD)),
		LineItems: []*stripe.TaxCalculationLineItemParams{
			{
				Amount:    stripe.Int64(cartTotal),
				Reference: stripe.String("Generic-Wagon"), // In real app, iterate items
			},
		},
		CustomerDetails: &stripe.TaxCalculationCustomerDetailsParams{
			Address: &stripe.AddressParams{
				State:   stripe.String(customerState),
				Country: stripe.String("US"),
				Line1: stripe.String("123 Main St"), // Required by Stripe Tax API for precision, usually passed from checkout
				City: stripe.String("San Francisco"),
				PostalCode: stripe.String("94111"),
			},
			AddressSource: stripe.String("shipping"),
		},
	}
	
	result, err := calculation.New(params)
	if err != nil {
		log.Printf("Stripe Tax Error: %v", err)
		return 0 // Fallback
	}
	
	return result.TaxAmountExclusive
}

// FileServer conveniently sets up a http.FileServer handler to serve
// static files from a http.FileSystem.
func FileServer(r chi.Router, path string, root http.FileSystem) {
	if strings.ContainsAny(path, "{}*") {
		panic("FileServer does not permit any URL parameters.")
	}

	if path != "/" && path[len(path)-1] != '/' {
		r.Get(path, http.RedirectHandler(path+"/", 301).ServeHTTP)
		path += "/"
	}
	path += "*"

	r.Get(path, func(w http.ResponseWriter, r *http.Request) {
		rctx := chi.RouteContext(r.Context())
		pathPrefix := strings.TrimSuffix(rctx.RoutePattern(), "/*")
		fs := http.StripPrefix(pathPrefix, http.FileServer(root))
		fs.ServeHTTP(w, r)
	})
}
