FROM golang:1.21-alpine

# Add wget for healthcheck
RUN apk add --no-cache wget curl

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download all dependencies
RUN go mod download

# Copy the source code
COPY *.go ./

# Build the application
RUN go build -o main .

# Add healthcheck
#HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
#    CMD wget -q --spider http://localhost:8899/health || exit 1  # Change port to 8899 for v2

# Run the application
CMD ["./main"]