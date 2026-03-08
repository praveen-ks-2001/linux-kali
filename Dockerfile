FROM kalilinux/kali-rolling

# Default port for ttyd web terminal (Railway overrides this with its own PORT)
ENV PORT=7681
# Prevent apt from prompting during build
ENV DEBIAN_FRONTEND=noninteractive

# Install base utilities + tini (init process manager)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates wget curl git \
     python3 python3-pip \
     tini fastfetch \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install common Kali tools
# Split into separate RUN to make layer caching more efficient during rebuilds
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     # Network scanning & enumeration
     nmap netcat-traditional dnsutils whois \
     # Web & HTTP tools
     curl wget sqlmap nikto \
     # Password & hash tools
     john hashcat hydra \
     # Exploitation framework
     metasploit-framework \
     # Misc utilities
     tmux vim nano net-tools iputils-ping \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download ttyd binary — picks the correct one based on CPU architecture (x86 or ARM)
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64|amd64) ttyd_asset="ttyd.x86_64" ;; \
      aarch64|arm64) ttyd_asset="ttyd.aarch64" ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    mkdir -p /usr/local/bin && \
    wget -qO /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/${ttyd_asset}" \
    && chmod +x /usr/local/bin/ttyd

# Run fastfetch on every new terminal session to display system info
RUN echo "fastfetch || true" >> /root/.bashrc

# tini is used as the init process (PID 1) so that:
# - zombie processes are properly reaped
# - signals like SIGTERM are correctly forwarded to ttyd on container shutdown
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start ttyd web terminal:
# -lc = login shell (sources .bashrc and .profile)
# --writable = allow keyboard input in terminal
# -i 0.0.0.0 = bind to all interfaces so Railway can route traffic in
# -c = basic auth using USERNAME and PASSWORD env variables
CMD ["/bin/bash", "-lc", "/usr/local/bin/ttyd --writable -i 0.0.0.0 -p ${PORT} -c ${USERNAME}:${PASSWORD} /bin/bash"]