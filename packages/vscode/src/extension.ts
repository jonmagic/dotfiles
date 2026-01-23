import * as vscode from "vscode"

import { createDailyProjectNote } from "@jonmagic/brain-core"

export function activate(context: vscode.ExtensionContext): void {
  const disposable = vscode.commands.registerCommand(
    "jonmagic.brain.createDailyProjectNote",
    async () => {
      const title = await vscode.window.showInputBox({
        title: "Create Daily Project Note",
        prompt: "Title for the new Daily Project note",
        placeHolder: "refactor stale queue cleanup"
      })

      if (!title?.trim()) {
        return
      }

      try {
        const result = await createDailyProjectNote({ title })
        const doc = await vscode.workspace.openTextDocument(
          vscode.Uri.file(result.filePath)
        )
        await vscode.window.showTextDocument(doc, { preview: false })
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        await vscode.window.showErrorMessage(message)
      }
    }
  )

  context.subscriptions.push(disposable)
}

export function deactivate(): void {
  // no-op
}
