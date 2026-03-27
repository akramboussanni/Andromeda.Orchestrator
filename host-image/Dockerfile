FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        unzip \
        xz-utils \
        procps \
        gosu \
        wine64 \
        wine32 \
        winbind \
        xvfb \
        lib32gcc-s1 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash andromeda

ENV STEAMCMD_DIR=/opt/steamcmd \
    GAME_DIR=/data/game \
    WINEPREFIX=/data/wineprefix \
    MELONLOADER_DIR=/data/melonloader \
    MODS_DIR=/data/mods \
    EOB_APP_ID=999860

RUN mkdir -p /opt/andromeda /data /home/andromeda/.steam \
    && chown -R andromeda:andromeda /opt/andromeda /data /home/andromeda/.steam

# Volume for Steam login cache (persists credentials between container runs)
VOLUME ["/home/andromeda/.steam"]

COPY scripts/install_steamcmd.sh /opt/andromeda/install_steamcmd.sh
COPY scripts/bootstrap_game.sh /opt/andromeda/bootstrap_game.sh
COPY scripts/install_melonloader.sh /opt/andromeda/install_melonloader.sh
COPY scripts/install_andromeda_mod.sh /opt/andromeda/install_andromeda_mod.sh

RUN chmod +x /opt/andromeda/*.sh

WORKDIR /data/game
ENTRYPOINT ["/opt/andromeda/bootstrap_game.sh"]
