# Both themes on the runner's own wallpaper and on a plain white desktop; one folder per case.
foreach ($theme in 'light', 'dark') {
  foreach ($bg in 'default', 'white') {
    & ./tools/window-shots.ps1 -Theme $theme -Background $bg -Out "shots\$theme-$bg"
  }
}
