import * as vscode from "vscode"

import { createDailyProjectNote } from "@jonmagic/brain-core"
import { getWorkspaceCache, disposeWorkspaceCache } from "./cache/workspaceCache"
import { WikilinkDocumentLinkProvider } from "./features/DocumentLinkProvider"
import { registerOpenDocumentCommand } from "./commands/openDocumentByReference"

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  // Initialize workspace cache
  const cache = getWorkspaceCache()
  await cache.initialize()

  // Register document link provider for wikilinks
  const linkProvider = new WikilinkDocumentLinkProvider()
  context.subscriptions.push(
    vscode.languages.registerDocumentLinkProvider(
      { language: "markdown" },
      linkProvider
    )
  )

  // Register open document by reference command
  registerOpenDocumentCommand(context)

  // Register daily project note command
  const createNoteDisposable = vscode.commands.registerCommand(
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

  context.subscriptions.push(createNoteDisposable)
}

export function deactivate(): void {
  disposeWorkspaceCache()
}
