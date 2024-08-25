FROM node:20.12.1-bullseye-slim


WORKDIR /excalidraw-brute-export-cli

RUN apt-get -y update && apt-get -y --no-install-recommends install bash && \
  apt-get -y clean && \
  apt-get -y autoremove && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /excalidraw-brute-export-cli && \
  chmod -R a+wrX /excalidraw-brute-export-cli && \
  chown -R node:node /excalidraw-brute-export-cli && \
  npx --yes playwright install-deps


COPY --chown=node:node . /excalidraw-brute-export-cli

USER node
# ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
# ENV PATH=/home/node/.npm-global/bin:$PATH
WORKDIR /excalidraw-brute-export-cli
RUN npm install . && npx playwright install

# This is where the user will mount their data to.
WORKDIR /data

ENTRYPOINT ["npx", "--prefix", "/excalidraw-brute-export-cli", "excalidraw-brute-export-cli"]
CMD ["--help"]
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD npx excalidraw-brute-export-cli --version || exit 1
