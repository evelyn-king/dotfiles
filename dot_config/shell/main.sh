# main.sh - entry point to bash/zsh shell config

shell_config_mode="${1:-auto}"
case "${shell_config_mode}" in
  auto)
    case "$-" in
      *i*)
        shell_config_mode="interactive"
        ;;
      *)
        shell_config_mode="profile"
        ;;
    esac
    ;;
  interactive|profile) ;;
  *)
    return 1
    ;;
esac

shell_config_source_stage() {
  local stage="$1"
  shift

  export SHELL_CONFIG_STAGE="${stage}"
  for shell_config_file in "$@"; do
    if [[ -f "${HOME}/.config/shell/${shell_config_file}" ]]; then
      . "${HOME}/.config/shell/${shell_config_file}"
    fi
  done
  unset SHELL_CONFIG_STAGE
}

if [[ -z "${__SHELL_CONFIG_ENV_LOADED:-}" ]]; then
  export __SHELL_CONFIG_ENV_LOADED=1
  shell_config_source_stage env \
    00_options.sh \
    10_init.sh \
    20_profile_env.sh \
    40_toolchains.sh
fi

if [[ "${shell_config_mode}" == "profile" && -z "${__SHELL_CONFIG_LOGIN_LOADED:-}" ]]; then
  export __SHELL_CONFIG_LOGIN_LOADED=1
  shell_config_source_stage login \
    30_keychain.sh
fi

if [[ "${shell_config_mode}" == "interactive" && -z "${__SHELL_CONFIG_INTERACTIVE_LOADED:-}" ]]; then
  export __SHELL_CONFIG_INTERACTIVE_LOADED=1
  shell_config_source_stage interactive \
    30_keychain.sh \
    60_exports.sh \
    70_python.sh \
    80_misc.sh \
    90_aliases.sh \
    99_finish.sh
fi
