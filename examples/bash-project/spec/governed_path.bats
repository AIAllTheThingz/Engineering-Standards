#!/usr/bin/env bats

BATS_TEST_FILENAME=${BATS_TEST_FILENAME:-}
BATS_TEST_TMPDIR=${BATS_TEST_TMPDIR:-}
status=${status:-0}
output=${output:-}

setup() {
  project_root=$(
    unset CDPATH
    cd -- "${BATS_TEST_FILENAME%/*}/.." && pwd -P
  )
  repository_root="$project_root/fixtures/repository"
  utility="$project_root/cmd/governed-path"
}

function resolves_an_existing_relative_path { # @test
  run "$utility" "$repository_root" 'alpha.txt'
  [ "$status" -eq 0 ]
  [ "$output" = "$repository_root/alpha.txt" ]
}

function preserves_spaces_as_one_argument { # @test
  run "$utility" --require-file "$repository_root" 'nested/space name.txt'
  [ "$status" -eq 0 ]
  [ "$output" = "$repository_root/nested/space name.txt" ]
}

function accepts_a_nonexistent_path_within_the_boundary { # @test
  run "$utility" "$repository_root" 'nested/future.txt'
  [ "$status" -eq 0 ]
  [ "$output" = "$repository_root/nested/future.txt" ]
}

function rejects_traversal { # @test
  run "$utility" "$repository_root" '../outside.txt'
  [ "$status" -ne 0 ]
  [[ $output == *'unsafe component'* ]]
}

function rejects_an_absolute_candidate { # @test
  run "$utility" "$repository_root" '/etc/passwd'
  [ "$status" -ne 0 ]
  [[ $output == *'relative path'* ]]
}

function rejects_a_trailing_separator_for_a_required_file { # @test
  run "$utility" --require-file "$repository_root" 'alpha.txt/'
  [ "$status" -ne 0 ]
  [[ $output == *'unsafe component'* ]]
}

function rejects_a_missing_required_file { # @test
  run "$utility" --require-file "$repository_root" 'nested/missing.txt'
  [ "$status" -ne 0 ]
  [[ $output == *'existing regular file'* ]]
}

function rejects_a_symlink_to_an_in_root_file { # @test
  local temporary_repository="$BATS_TEST_TMPDIR/file-symlink-repository"
  mkdir -p "$temporary_repository"
  printf 'fixture\n' > "$temporary_repository/target.txt"
  ln -s target.txt "$temporary_repository/alias.txt"
  run "$utility" --require-file "$temporary_repository" 'alias.txt'
  [ "$status" -ne 0 ]
  [[ $output == *'must not contain symbolic links'* ]]
}

function rejects_a_symlinked_directory_component { # @test
  local temporary_repository="$BATS_TEST_TMPDIR/directory-symlink-repository"
  mkdir -p "$temporary_repository/real"
  printf 'fixture\n' > "$temporary_repository/real/target.txt"
  ln -s real "$temporary_repository/alias"
  run "$utility" --require-file "$temporary_repository" 'alias/target.txt'
  [ "$status" -ne 0 ]
  [[ $output == *'must not contain symbolic links'* ]]
}

function rejects_a_symlinked_repository_root { # @test
  local root_alias="$BATS_TEST_TMPDIR/repository-root-alias"
  ln -s "$repository_root" "$root_alias"
  run "$utility" --require-file "$root_alias" 'alpha.txt'
  [ "$status" -ne 0 ]
  [[ $output == *'repository root must be a real directory'* ]]
}

function propagates_a_child_command_failure { # @test
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\nexit 73\n' > "$BATS_TEST_TMPDIR/bin/realpath"
  chmod 700 "$BATS_TEST_TMPDIR/bin/realpath"
  run env PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin" "$utility" "$repository_root" 'alpha.txt'
  [ "$status" -ne 0 ]
  [[ $output == *'could not be resolved'* ]]
}
