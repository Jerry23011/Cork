//
//  Maintenance View.swift
//  Cork
//
//  Created by David Bureš on 13.02.2023.
//

import SwiftUI

enum RegexError: Error
{
    case foundNilRange
}

enum MaintenanceSteps
{
    case ready, maintenanceRunning, finished
}

struct MaintenanceView: View
{
    @Binding var isShowingSheet: Bool

    @State var maintenanceSteps: MaintenanceSteps = .ready

    @State var currentMaintenanceStepText: String = "Firing up..."

    @State var shouldPurgeCache: Bool = true
    @State var shouldUninstallOrphans: Bool = true
    @State var shouldPerformHealthCheck: Bool = false
    
    @State var numberOfOrphansRemoved: Int = 0
    
    @State var cachePurgingSkippedPackagesDueToMostRecentVersionsNotBeingInstalled: Bool = false
    @State var brewHealthCheckFoundNoProblems: Bool = false
    
    @State var maintenanceFoundNoProblems: Bool = true

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            switch maintenanceSteps
            {
            case .ready:
                SheetWithTitle(title: "Perform Brew maintenance")
                {
                    VStack(alignment: .leading, spacing: 10)
                    {
                        Form
                        {
                            LabeledContent("Packages:")
                            {
                                VStack(alignment: .leading)
                                {
                                    Toggle(isOn: $shouldUninstallOrphans)
                                    {
                                        Text("Uninstall orphaned packages")
                                    }
                                    Toggle(isOn: $shouldPurgeCache)
                                    {
                                        Text("Purge Brew cache")
                                    }
                                }
                            }

                            LabeledContent("Other:")
                            {
                                Toggle(isOn: $shouldPerformHealthCheck)
                                {
                                    Text("Perform health check")
                                }
                            }
                        }

                        HStack
                        {
                            DismissSheetButton(isShowingSheet: $isShowingSheet)

                            Spacer()

                            Button
                            {
                                print("Start")
                                maintenanceSteps = .maintenanceRunning
                            } label: {
                                Text("Start Maintenance")
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                }
                .padding()

            case .maintenanceRunning:
                ProgressView
                {
                    Text(currentMaintenanceStepText)
                        .onAppear
                        {
                            Task
                            {
                                if shouldUninstallOrphans
                                {
                                    currentMaintenanceStepText = "Uninstalling Orphans..."
                                    
                                    do
                                    {
                                        let orphanUninstallationOutput = try await uninstallOrphanedPackages()
                                        
                                        print("Orphan removal output: \(orphanUninstallationOutput)")
                                        
                                        let numberOfUninstalledOrphansRegex: String = "(?<=Autoremoving ).*?(?= unneeded)"
                                        guard let matchedRange = orphanUninstallationOutput.standardOutput.range(of: numberOfUninstalledOrphansRegex, options: .regularExpression) else { throw RegexError.foundNilRange }
                                        let numberOfUninstalledOrphansString = String(orphanUninstallationOutput.standardOutput[matchedRange])
                                        numberOfOrphansRemoved = Int(numberOfUninstalledOrphansString) ?? 0
                                        
                                    }
                                    catch let orphanUninstallatioError as NSError
                                    {
                                        print(orphanUninstallatioError)
                                    }
                                    
                                } else {
                                    print("Will not uninstall orphans")
                                }

                                if shouldPurgeCache
                                {
                                    currentMaintenanceStepText = "Purging Cache..."
                                    
                                    let cachePurgeOutput = try await purgeBrewCache()
                                    print("Cache purge output: \(cachePurgeOutput)")
                                    
                                    if cachePurgeOutput.standardError.contains("Warning: Skipping")
                                    {
                                        cachePurgingSkippedPackagesDueToMostRecentVersionsNotBeingInstalled = true
                                    }

                                } else {
                                    print("Will not purge cache")
                                }

                                if shouldPerformHealthCheck
                                {
                                    currentMaintenanceStepText = "Running Health Check..."
                                    
                                    do
                                    {
                                        let healthCheckOutput = try await performBrewHealthCheck()
                                        print("Health check output: \(healthCheckOutput)")
                                        
                                        brewHealthCheckFoundNoProblems = true
                                        
                                    }
                                    catch let healthCheckError as NSError
                                    {
                                        print(healthCheckError)
                                    }
                                } else {
                                    print("Will not perform health check")
                                }
                                
                                maintenanceSteps = .finished
                            }
                        }
                }
                .padding()
                .frame(width: 200)

            case .finished:
                ComplexWithIcon(systemName: "checkmark.seal")
                {
                    VStack(alignment: .center)
                    {
                        VStack(alignment: .leading, spacing: 5)
                        {
                            Text("Maintenance finished")
                                .font(.headline)

                            if shouldUninstallOrphans
                            {
                                if numberOfOrphansRemoved == 0
                                {
                                    Text("No orphaned packages found")
                                } else {
                                    Text("\(numberOfOrphansRemoved) orphaned packages removed")
                                }
                            }
                            
                            if shouldPurgeCache
                            {
                                Text("Package cache purged")
                                
                                if cachePurgingSkippedPackagesDueToMostRecentVersionsNotBeingInstalled
                                {
                                    Text("Some package caches were not purged because they were held back by some packages not being updated")
                                        .font(.caption)
                                        .foregroundColor(Color(nsColor: NSColor.systemGray))
                                }
                            }
                            

                            if shouldPerformHealthCheck
                            {
                                if brewHealthCheckFoundNoProblems
                                {
                                    Text("No problems with Homebrew found")
                                }
                                else
                                {
                                    Text("There were some problems with Homebrew")
                                        .onAppear
                                        {
                                        maintenanceFoundNoProblems = false
                                        }
                                }
                            }
                        }
                        .frame(maxWidth: 200)
    
                        Spacer()
                        
                        HStack
                        {
                            Spacer()
                            
                            Button {
                                isShowingSheet.toggle()
                            } label: {
                                Text("Close")
                            }
                            .keyboardShortcut(.defaultAction)

                        }
                    }
                }
                .padding()
                .frame(minWidth: 300, minHeight: 150)
            }
        }
    }
}