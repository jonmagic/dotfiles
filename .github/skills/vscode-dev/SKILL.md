# vscode-dev

Build, package, and install the jonmagic-brain VSCode extension for local development.

## When to Use

Use this skill when:
- Iterating on the VSCode extension at `~/.dotfiles/packages/vscode`
- Testing changes to wikilink completion, document links, or other extension features
- The user says "rebuild the extension", "install the extension", or "test the extension"

## Workflow

1. **Build** the extension:
   ```bash
   cd ~/.dotfiles/packages/vscode && bun run build
   ```

2. **Package** as VSIX:
   ```bash
   cd ~/.dotfiles/packages/vscode && vsce package --no-dependencies
   ```

3. **Install** in VSCode Insiders:
   ```bash
   cd ~/.dotfiles/packages/vscode && code-insiders --install-extension jonmagic-brain-0.0.0.vsix --force
   ```

4. **Notify user** to reload VSCode:
   > Extension installed. Reload VSCode with `Cmd+Shift+P` → "Developer: Reload Window"

## One-liner

For quick iteration, run all steps:
```bash
cd ~/.dotfiles/packages/vscode && bun run build && vsce package --no-dependencies && code-insiders --install-extension jonmagic-brain-0.0.0.vsix --force
```

## Notes

- The VSIX filename is `jonmagic-brain-0.0.0.vsix` (not `jonmagic-brain-vscode-*`)
- User must manually reload VSCode after installation
- Build output goes to `dist/extension.js`
- If build fails, check for TypeScript errors first
