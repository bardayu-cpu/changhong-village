#!/bin/zsh
set -u
ayu_root="${0:A:h:h}"
ayu_godot="${AYU_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
ayu_evidence="$ayu_root/ayu_home/evidence"
mkdir -p "$ayu_evidence"
ayu_fail=0
for ayu_name in test_home test_activities test_actors test_assets test_integration; do
  perl -e 'alarm shift; exec @ARGV' 120 "$ayu_godot" --headless --path "$ayu_root" --log-file "/private/tmp/ayu-${ayu_name}-engine.log" --script "res://ayu_home/tests/$ayu_name.gd" > "$ayu_evidence/$ayu_name.log" 2>&1
  ayu_exit=$?
  if [[ $ayu_exit -eq 0 ]] && rg -q 'RESULT PASS|ACTIVITIES_PASS|ACTORS_PASS' "$ayu_evidence/$ayu_name.log" && ! rg -q 'SCRIPT ERROR|Parse Error|Compile Error|RESULT FAIL|Assertion failed' "$ayu_evidence/$ayu_name.log"; then
    print "PASS $ayu_name"
  else
    print "FAIL $ayu_name (exit $ayu_exit): $ayu_evidence/$ayu_name.log"
    ayu_fail=$((ayu_fail+1))
  fi
done
if [[ "$ayu_fail" -eq 0 ]]; then print 'RESULT PASS AYU_HOME 5 suites'; else print "RESULT FAIL AYU_HOME $ayu_fail suites"; fi
exit "$ayu_fail"
