# Dockerfile.nix - Build Nix packages and copy to Alpine runtime
# This gives us both Nix reproducibility AND a proper FHS base

FROM nixos/nix:latest AS builder

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /build
COPY flake.nix flake.lock* ./
COPY docker/ ./docker/
COPY magento-theme/ ./magento-theme/

# Build just the runtime packages (not the container image)
RUN nix build --accept-flake-config .#container

# Extract the closure of all runtime dependencies
RUN mkdir -p /nix-export
RUN nix copy --to /nix-export --no-check-sigs $(nix path-info --accept-flake-config .#container -r)

# Runtime image - Alpine with Nix store copied in
FROM alpine:3.20

# Install minimal runtime deps
RUN apk add --no-cache bash coreutils

# Copy the Nix store from builder
COPY --from=builder /nix /nix

# Create FHS symlinks
RUN mkdir -p /lib64 && \
    ln -sf /nix/store/*-glibc-*/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 2>/dev/null || true

# Copy start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /var/www/html

# Set PATH to include Nix binaries
ENV PATH="/nix/store/*/bin:$PATH"

EXPOSE 8080

CMD ["/bin/bash", "/start.sh"]
