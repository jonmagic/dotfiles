-- Open terminal and vscode-insiders to the specified path.
--
-- params
--   path - the path to open in terminal and vscode-insiders
--
-- Returns nothing.
function openGitHubProject(params)
  local path = params.path or ""
  local fullPath = "~/github/" .. path

  local appleScript = [[
    tell application "iTerm"
      create window with default profile
      tell current session of current window
        write text "cd ]] .. fullPath .. [["
      end tell
    end tell
  ]]
  hs.osascript.applescript(appleScript)
  hs.execute("open -a Visual\\ Studio\\ Code\\ -\\ Insiders " .. fullPath)

  local primaryScreen = hs.screen.primaryScreen()
  local isExternalMonitor = primaryScreen:name() ~= hs.screen.mainScreen():name()

  local function waitForIterm()
    local iTerm = hs.application.find("iTerm")
    if iTerm then
      if not isExternalMonitor then
        iTerm:mainWindow():maximize()
      else
        local iTermWindow = iTerm:mainWindow()
        iTermWindow:setFrame(primaryScreen:frame())
        iTermWindow:moveToUnit(hs.layout.right50)
      end
      return true
    end
    return false
  end

  local function waitForVscode()
    local vscode = hs.application.find("Visual Studio Code - Insiders")
    if vscode then
      if not isExternalMonitor then
        vscode:mainWindow():maximize()
      else
        local vscodeWindow = vscode:mainWindow()
        vscodeWindow:setFrame(primaryScreen:frame())
        vscodeWindow:moveToUnit(hs.layout.left50)
      end
      return true
    end
    return false
  end

  hs.timer.waitUntil(waitForIterm, 0.2, 5)
  hs.timer.waitUntil(waitForVscode, 0.2, 5)
end

hs.urlevent.bind("openGitHubProject", function(eventName, params)
    openGitHubProject(params)
end)
