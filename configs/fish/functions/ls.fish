function ls
  if type -q eza
    eza -la $argv
  else
    command ls -la $argv
  end
end
