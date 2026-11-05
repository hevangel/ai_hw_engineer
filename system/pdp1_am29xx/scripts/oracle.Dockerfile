FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq \
    libsdl2-2.0-0 libedit2 libpng16-16 libstdc++6 python3 && \
    rm -rf /var/lib/apt/lists/*
COPY bin_pdp1 /usr/local/bin/pdp1
RUN chmod +x /usr/local/bin/pdp1
WORKDIR /work
CMD ["/usr/local/bin/pdp1"]
