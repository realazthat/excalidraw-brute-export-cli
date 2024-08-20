FROM node:20.12.1-bullseye-slim


WORKDIR /excalidraw-brute-export-cli

RUN apt-get -y update && apt-get -y --no-install-recommends install bash && \
  apt-get -y clean && \
  apt-get -y autoremove && \
  rm -rf /var/lib/apt/lists/* && \
  useradd -m -d /home/user -s /bin/bash user && \
  mkdir -p /home/user/.local && \
  chown -R user:user /excalidraw-brute-export-cli /home/user/.local && \
  chmod -R a+wrX /excalidraw-brute-export-cli

COPY --chown=user:user . /excalidraw-brute-export-cli
USER user
ENV NPM_CONFIG_PREFIX=/home/user/.npm-global
ENV PATH=/home/user/.npm-global/bin:$PATH
WORKDIR /excalidraw-brute-export-cli
RUN npm install -g .

# This is where the user will mount their data to.
WORKDIR /data

ENTRYPOINT ["npx", "excalidraw-brute-export-cli"]
CMD ["--help"]
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD npx excalidraw-brute-export-cli --version || exit 1
