#!/usr/bin/env bats
# Tests for lib/util/adf.py — ADF-to-text conversion

setup() {
  export ADF_PY="${BATS_TEST_DIRNAME}/../bin/lib/util/adf.py"
  export FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
}

@test "converts simple paragraph" {
  run bash -c 'echo '"'"'{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello world"}]}]}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == "Hello world" ]]
}

@test "converts multiple paragraphs with newlines" {
  run bash -c 'echo '"'"'{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"First"}]},{"type":"paragraph","content":[{"type":"text","text":"Second"}]}]}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == *"First"* ]]
  [[ "$output" == *"Second"* ]]
}

@test "converts headings" {
  run bash -c 'echo '"'"'{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Title"}]}]}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == "Title" ]]
}

@test "converts bullet lists" {
  run bash -c 'echo '"'"'{"type":"doc","content":[{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Item A"}]}]},{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Item B"}]}]}]}]}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == *"Item A"* ]]
  [[ "$output" == *"Item B"* ]]
}

@test "converts hardBreak" {
  run bash -c 'echo '"'"'{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Before"},{"type":"hardBreak"},{"type":"text","text":"After"}]}]}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == *"Before"* ]]
  [[ "$output" == *"After"* ]]
}

@test "handles empty input" {
  run bash -c 'echo '"'"'{}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == "" ]]
}

@test "handles null content" {
  run bash -c 'echo '"'"'{"type":"doc","content":[]}'"'"' | python3 "$ADF_PY"'
  [[ "$output" == "" ]]
}

@test "--field extracts description from issue JSON" {
  run bash -c 'cat "$FIXTURES/issue-get.json" | python3 "$ADF_PY" --field description'
  [[ "$output" == *"Overview"* ]]
  [[ "$output" == *"This is the description of feature A."* ]]
  [[ "$output" == *"Item one"* ]]
  [[ "$output" == *"Item two"* ]]
}

@test "--field handles hardBreak in description" {
  run bash -c 'cat "$FIXTURES/issue-get.json" | python3 "$ADF_PY" --field description'
  [[ "$output" == *"Line before break"* ]]
  [[ "$output" == *"Line after break"* ]]
}

@test "--comments extracts comment bodies" {
  run bash -c 'cat "$FIXTURES/comments.json" | python3 "$ADF_PY" --comments'
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [[ "$count" == "3" ]]
}

@test "--comments includes author and body text" {
  run bash -c 'cat "$FIXTURES/comments.json" | python3 "$ADF_PY" --comments'
  [[ "$output" == *"Alice Smith"* ]]
  [[ "$output" == *"Started working on this."* ]]
  [[ "$output" == *"Review comments addressed."* ]]
}

@test "--comments with --since-days filters by date" {
  # Use a large since-days to get all
  run bash -c 'cat "$FIXTURES/comments.json" | python3 "$ADF_PY" --comments --since-days 365'
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [[ "$count" == "3" ]]
}

@test "--issues extracts descriptions from search results" {
  run bash -c 'cat "$FIXTURES/sprint-issues.json" | python3 "$ADF_PY" --issues'
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [[ "$count" == "3" ]]
}
