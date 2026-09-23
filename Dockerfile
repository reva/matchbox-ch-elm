FROM europe-west6-docker.pkg.dev/ahdis-ch/ahdis/matchbox:v4.1.13

COPY ./src/application.yaml /config
COPY ./src/*.tgz /

# Use root to maintain the system
USER root

# Update packages, in case the Matchbox image is too old
RUN apt update && apt upgrade -y

# Remove the package management tools for security reasons
#RUN dpkg -r --force-all apt apt-get && dpkg -r --force-all debconf dpkg

# Switch back to the matchbox user
USER matchbox

EXPOSE 80

# Install the IG packages and warm both caches, in a single layer.
#
# Two things are prepared here:
#   * the HAPI package database (/database/h2.mv.db), which --only_install_packages
#     already did before, and
#   * the FHIR filesystem package cache (~/.fhir) used by org.hl7.fhir.core's
#     FilesystemPackageCacheManager, which was not prepared and was therefore
#     rebuilt, SQLite package indexes included, on every container start.
#
# Measured over four alternating runs on one host, 8 CPU and -Xmx6g: 127.5s
# average to readiness without the warm cache, 111.8s with it, so about 16s or
# 12%. The ranges overlap (119-135s against 100-122s), so treat that as an
# indication rather than a precise figure.
#
# Both run in one RUN on purpose. The warm-up rewrites the 435 MB h2.mv.db, and
# a separate layer would store a second full copy of it, adding ~530 MB to the
# image instead of the ~95 MB the cache actually needs.
#
# The warm-up needs more heap than the install: installing only writes packages
# to the database, while a full startup holds the whole CH ELM dependency
# closure in memory, about 3 GB on its own, and -Xmx3G dies with an
# OutOfMemoryError while building the engines.
#
# Port 8080 avoids depending on binding a privileged port during the build. The
# server is stopped as soon as the readiness probe reports the engine is up.
RUN set -eu; \
    java -Xmx3G -Xms1G -jar /matchbox.jar --hapi.fhir.only_install_packages=true; \
    java -Xmx6G -Xms1G -jar /matchbox.jar --server.port=8080 > /tmp/warmup.log 2>&1 & \
    app=$!; \
    ready=0; \
    for _ in $(seq 1 300); do \
        if ! kill -0 "$app" 2>/dev/null; then echo "matchbox exited during cache warmup"; tail -60 /tmp/warmup.log; exit 1; fi; \
        if curl -sf -o /dev/null http://localhost:8080/matchboxv3/actuator/health/readiness; then ready=1; break; fi; \
        sleep 2; \
    done; \
    kill "$app" 2>/dev/null || true; \
    wait "$app" 2>/dev/null || true; \
    if [ "$ready" -ne 1 ]; then echo "matchbox never became ready during cache warmup"; tail -60 /tmp/warmup.log; exit 1; fi; \
    rm -f /tmp/warmup.log /database/h2.trace.db; \
    du -sh /database "$HOME/.fhir"
