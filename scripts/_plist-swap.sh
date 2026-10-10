# Sourced by ui-tests.sh and screenshots.sh: runs with the fake CI plist and puts the real one back afterwards.
# The backup lives in build-output/ (not a temp dir) so a run that was killed can be undone by the next run,
# instead of silently leaving the fake plist in place.
PLIST=FoodPlanner/GoogleService-Info.plist
SAVED=build-output/GoogleService-Info.plist.real
mkdir -p build-output

if [ -f "$SAVED" ]; then
  echo "Restoring the real GoogleService-Info.plist left by an interrupted run"
  cp "$SAVED" "$PLIST"
  rm -f "$SAVED"
fi

# Only back up a real plist; the fake one needs no saving.
if [ -f "$PLIST" ] && ! cmp -s "$PLIST" ci/GoogleService-Info.plist; then cp "$PLIST" "$SAVED"; fi
restore_plist() {
  if [ -f "$SAVED" ]; then cp "$SAVED" "$PLIST"; rm -f "$SAVED"; elif ! [ -s "$PLIST" ] || cmp -s "$PLIST" ci/GoogleService-Info.plist; then rm -f "$PLIST"; fi
}
trap restore_plist EXIT INT TERM
cp ci/GoogleService-Info.plist "$PLIST"
