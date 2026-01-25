// Decorator to visually simplify UID-based wikilinks.
// Shows [[uid:xxx|Display Text]] as just [[Display Text]] in the editor.

import * as vscode from "vscode"
import { WIKILINK_REGEX, UID_PREFIX } from "@jonmagic/brain-core"

// Decoration type that hides the uid: prefix portion
const hiddenDecorationType = vscode.window.createTextEditorDecorationType({
  textDecoration: "none",
  opacity: "0",
  letterSpacing: "-1000px", // Effectively collapses the text
})

export class WikilinkDecorator {
  private disposables: vscode.Disposable[] = []

  activate(context: vscode.ExtensionContext): void {
    // Update decorations when active editor changes
    this.disposables.push(
      vscode.window.onDidChangeActiveTextEditor((editor) => {
        if (editor) {
          this.updateDecorations(editor)
        }
      })
    )

    // Update decorations when document changes
    this.disposables.push(
      vscode.workspace.onDidChangeTextDocument((event) => {
        const editor = vscode.window.activeTextEditor
        if (editor && event.document === editor.document) {
          this.updateDecorations(editor)
        }
      })
    )

    // Initial decoration for current editor
    if (vscode.window.activeTextEditor) {
      this.updateDecorations(vscode.window.activeTextEditor)
    }

    context.subscriptions.push(...this.disposables)
  }

  private updateDecorations(editor: vscode.TextEditor): void {
    if (editor.document.languageId !== "markdown") {
      return
    }

    const text = editor.document.getText()
    const decorations: vscode.DecorationOptions[] = []

    // Find all UID-based wikilinks
    const regex = new RegExp(WIKILINK_REGEX.source, "g")
    let match: RegExpExecArray | null

    while ((match = regex.exec(text)) !== null) {
      const target = match[1]
      if (!target || !target.startsWith(UID_PREFIX)) {
        continue
      }

      // Find the pipe separator
      const pipeIndex = target.indexOf("|")
      if (pipeIndex === -1) {
        continue
      }

      // The range to hide: from "uid:" to "|" (inclusive of pipe)
      // Match format: [[uid:xxx|label]]
      // We want to hide "uid:xxx|"
      const matchStart = match.index
      const uidPartStart = matchStart + 2 // After [[
      const uidPartEnd = uidPartStart + pipeIndex + 1 // Include the |

      const startPos = editor.document.positionAt(uidPartStart)
      const endPos = editor.document.positionAt(uidPartEnd)

      decorations.push({
        range: new vscode.Range(startPos, endPos),
      })
    }

    editor.setDecorations(hiddenDecorationType, decorations)
  }

  dispose(): void {
    hiddenDecorationType.dispose()
    this.disposables.forEach((d) => d.dispose())
  }
}
