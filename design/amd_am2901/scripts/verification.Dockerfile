FROM ai-hw-engineer:latest
# The independently authored oracle is Java; the RTL tools are unchanged.
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-21-jdk-headless && rm -rf /var/lib/apt/lists/*
