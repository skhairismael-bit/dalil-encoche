#!/bin/bash
# Faux claude pour scripts/test-dalil-pont.sh : note ce qu'il reçoit, puis répond selon FAUX_MODE.
echo "$$" >> "$FAUX_DOSSIER/lancements"
echo "$DALIL_JETON" > "$FAUX_DOSSIER/jeton"
echo "$@" > "$FAUX_DOSSIER/args"
while IFS= read -r ligne; do
    echo "$ligne" >> "$FAUX_DOSSIER/questions"
    case "$FAUX_MODE" in
        muet) ;;
        meurt) echo "Not logged in" >&2; exit 1 ;;
        *) cat "$FAUX_FIXTURE" ;;
    esac
done
