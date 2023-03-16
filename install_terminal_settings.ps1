$path = $myInvocation.myCommand.path
$dotfiles = Split-Path $path -parent
$terminal = join-path -path $dotfiles -childPath terminal
$settings = join-path -path $terminal -childPath "settings.json"
$settings_dir = "$(env:localappdata)\packages\microsoft.windowsterminal_8wekyb3d8bbwe\LocalState"
write-host "copying $settings => $settings_dir"
copy-item $settings $settings_dir

