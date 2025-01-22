//
//  Sudo Required For REmoval.swift
//  Cork
//
//  Created by David Bureš on 19.11.2023.
//

import SwiftUI

struct SudoRequiredForRemovalSheet: View, Sendable
{
    @Environment(\.dismiss) var dismiss: DismissAction

    @EnvironmentObject var brewData: BrewDataStorage
    @EnvironmentObject var appState: AppState

    var body: some View
    {
        if let package = appState.packageTryingToBeUninstalledWithSudo
        {
            VStack(alignment: .leading)
            {
                ComplexWithImage(image: Image(localURL: URL(filePath: "/System/Library/CoreServices/KeyboardSetupAssistant.app/Contents/Resources/AppIcon.icns"))!)
                {
                    VStack(alignment: .leading, spacing: 10)
                    {
                        Text("add-package.uninstall.requires-sudo-password-\(package.name)")
                            .font(.headline)

                        ManualUninstallInstructions(package: package)
                    }
                }

                Text("add.package.uninstall.requires-sudo-password.terminal-instructions-\(package.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack
                {
                    Button
                    {
                        dismiss()

                        Task.detached
                        {
                            do
                            {
                                try await brewData.synchronizeInstalledPackages()
                            }
                            catch let synchronizationError
                            {
                                await appState.showAlert(errorToShow: .couldNotSynchronizePackages(error: synchronizationError.localizedDescription))
                            }
                        }
                    } label: {
                        Text("action.close")
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button
                    {
                        openTerminal()
                    } label: {
                        Text("action.open-terminal")
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .fixedSize()
        }
    }
}

private struct ManualUninstallInstructions: View
{
    let package: BrewPackage

    let isPurgingPackage: Bool = false

    var manualUninstallCommand: String
    {
        return "brew uninstall \(package.type == .cask ? "--cask" : "") \(isPurgingPackage ? "--zap" : "") \(package.name)"
    }

    var body: some View
    {
        VStack
        {
            Text("add-package.uninstall.requires-sudo-password.description")

            GroupBox
            {
                HStack(alignment: .center, spacing: 5)
                {
                    Text(manualUninstallCommand)

                    Divider()

                    Button
                    {
                        manualUninstallCommand.copyToClipboard()
                    } label: {
                        Label
                        {
                            Text("action.copy")
                        } icon: {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("action.copy-manual-install-command-to-clipboard")
                    }
                }
                .padding(3)
            }
        }
    }
}
