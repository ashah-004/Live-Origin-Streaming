FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY . .
RUN go build -o origin-server main.go

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/origin-server .
CMD ["./origin-server"]
