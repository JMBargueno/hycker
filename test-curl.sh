#!/bin/bash
echo "Testing CurseForge API..."
echo "API Key: $HYTALE_CURSEFORGE_API_KEY"
curl -v \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $HYTALE_CURSEFORGE_API_KEY" \
  -X POST \
  https://api.curseforge.com/v1/mods \
  -d '{"modIds":[1423494,1409811],"filterPcOnly":true}'