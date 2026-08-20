# Publish Checklist

- [ ] Run `powershell -ExecutionPolicy Bypass -File .\test.ps1`.
- [ ] Parse every JSON file and PowerShell script successfully.
- [ ] Search for user paths, tokens, browser profiles, speech models, logs, backups, and compiled binaries.
- [ ] Inspect every screenshot at native resolution and remove private content.
- [ ] Confirm icon, wallpaper, music, subtitle, and animal asset rights.
- [ ] Confirm the default profile keeps external components disabled.
- [ ] Test `install.ps1` without `-Apply` and confirm it is read-only.
- [ ] Test `restore.ps1 -Preview` before a real install.
- [ ] Test the package in a clean Windows 11 user profile or virtual machine.
- [ ] Review `git diff --stat` and `git status --short`.
- [ ] Commit only `open-source/obsidian-glass-desktop`.
- [ ] Push the feature branch and main branch only after the above checks pass.
