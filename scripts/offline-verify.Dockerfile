# Used only by verify-offline.ps1 -- proves an assembled box can actually answer a
# question with zero network access, in a genuinely network-isolated container
# (docker run --network none), not just by reading the code.
FROM node:20-bookworm-slim
# llama-server links against these at runtime (confirmed via ldd) -- present on a
# normal Ubuntu/Debian install, just stripped from this minimal base image.
# Installed here, at build time, with network available -- the whole point of the
# --network none run later is that nothing at *runtime* needs this.
RUN apt-get update && apt-get install -y --no-install-recommends libssl3 libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY . /box
WORKDIR /box/server
# node_modules in the box was installed on whatever host ran load-drive.ps1 --
# better-sqlite3 ships platform-native binaries, so if that host wasn't this
# container's own platform (e.g. load-drive.ps1 run on Windows/macOS to assemble a
# linux-x64 box), those binaries are wrong. Reinstalling here matches what a real
# linux-x64 machine running load-drive.ps1 itself would produce.
RUN rm -rf node_modules && npm install --omit=dev --no-audit --no-fund
WORKDIR /box
RUN chmod +x bin/llama-server launch.sh
CMD ["bash", "launch.sh"]
