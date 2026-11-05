#!/usr/bin/env bash
# Ranqueia os mirrors de novo (Arch e derivadas, Arch Linux ARM e Termux), sem refazer o resto do setup.
# Use depois do setup.sh inicial: bash ~/Minhas-Paradas/mirrors.sh [--dry-run]
exec bash "$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")/setup.sh" --mirrors "$@"
