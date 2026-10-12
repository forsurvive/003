#!/usr/bin/env bash
# Godot 고정 판본 설치 (SD-19 §6.2: 단계 T 착수 때 최신 안정판 마이너 고정, 이후 패치만).
# 컨테이너는 휘발성이라 세션마다 이 스크립트로 다시 설치한다.
set -euo pipefail
VER="4.7.2-stable"
SHA="8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e"
BIN="/opt/godot/Godot_v${VER}_linux.x86_64"
if [[ ! -x "$BIN" ]]; then
  mkdir -p /opt/godot && cd /opt/godot
  curl -sSL -o g.zip "https://github.com/godotengine/godot/releases/download/${VER}/Godot_v${VER}_linux.x86_64.zip"
  unzip -o -q g.zip && rm g.zip
fi
echo "${SHA}  ${BIN}" | sha256sum -c -
ln -sf "$BIN" /usr/local/bin/godot
godot --version
