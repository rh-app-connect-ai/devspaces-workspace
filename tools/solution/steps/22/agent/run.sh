# # Old runner
# camel run * \
# --dep=mvn:io.kaoto.forage:forage-agent:1.0 \
# --dep=mvn:io.kaoto.forage:forage-memory-message-window:1.0 \
# --dep=mvn:io.kaoto.forage:forage-model-open-ai:1.0 \
# --local-kamelet-dir ../../support/kamelets

# New Forage runner
camel forage run * --dep=mvn:io.kaoto.forage:forage-memory-message-window:1.1-SNAPSHOT