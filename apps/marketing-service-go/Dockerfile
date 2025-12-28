FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod tidy
RUN go build -o /bin/marketing-service ./cmd/server

FROM alpine:latest
COPY --from=builder /bin/marketing-service /bin/marketing-service
CMD ["/bin/marketing-service"]
