#!/usr/bin/env bash

# Resolve a repository-relative path without executing or modifying the target.
governed_path_resolve() {
  if (($# != 2)); then
    printf 'governed_path_resolve requires ROOT and RELATIVE_PATH\n' >&2
    return 64
  fi

  local requested_root=$1
  local relative_path=$2
  local resolved_root
  local resolved_path
  local candidate_path
  local part
  local -a components=()

  if [[ -z $requested_root || -z $relative_path || $relative_path == /* ]]; then
    printf 'root and a nonempty relative path are required\n' >&2
    return 65
  fi

  IFS='/' read -r -a components <<< "$relative_path"
  for part in "${components[@]}"; do
    if [[ -z $part || $part == '.' || $part == '..' ]]; then
      printf 'relative path contains an unsafe component\n' >&2
      return 65
    fi
  done

  if [[ -L $requested_root ]]; then
    printf 'repository root must be a real directory\n' >&2
    return 66
  fi
  if ! resolved_root=$(realpath -e -- "$requested_root"); then
    printf 'repository root could not be resolved\n' >&2
    return 66
  fi
  if [[ ! -d $resolved_root || -L $resolved_root ]]; then
    printf 'repository root must be a real directory\n' >&2
    return 66
  fi
  candidate_path=$resolved_root
  for part in "${components[@]}"; do
    candidate_path+="/$part"
    if [[ -L $candidate_path ]]; then
      printf 'candidate path must not contain symbolic links\n' >&2
      return 68
    fi
  done
  if ! resolved_path=$(realpath -m -- "$resolved_root/$relative_path"); then
    printf 'candidate path could not be resolved\n' >&2
    return 67
  fi
  if [[ $resolved_path != "$resolved_root"/* ]]; then
    printf 'candidate path escapes the repository root\n' >&2
    return 68
  fi

  printf '%s\n' "$resolved_path"
}

# Resolve a path and require a non-symlink regular file.
governed_path_require_file() {
  if (($# != 2)); then
    printf 'governed_path_require_file requires ROOT and RELATIVE_PATH\n' >&2
    return 64
  fi

  local resolved_path
  local resolve_status
  if resolved_path=$(governed_path_resolve "$1" "$2"); then
    :
  else
    resolve_status=$?
    return "$resolve_status"
  fi
  if [[ ! -f $resolved_path || -L $resolved_path ]]; then
    printf 'candidate must be an existing regular file\n' >&2
    return 69
  fi
  printf '%s\n' "$resolved_path"
}
