//
//  Bootstrap.swift
//  Carthage
//
//  Created by Justin Spahr-Summers on 2014-11-15.
//  Copyright (c) 2014 Carthage. All rights reserved.
//

import CarthageKit
import Commandant
import Foundation
import Result
import ReactiveCocoa

public struct BootstrapCommand: CommandType {
	public let verb = "bootstrap"
	public let function = "Check out and build the project's dependencies"

	public func run(options: UpdateCommand.Options) -> Result<(), CarthageError> {
		// Reuse UpdateOptions, since all `bootstrap` flags should correspond to
		// `update` flags.
		return options.loadProject()
			.flatMap(.Merge) { project -> SignalProducer<(), CarthageError> in
				if !NSFileManager.defaultManager().fileExistsAtPath(project.resolvedCartfileURL.path!) {
					let formatting = options.checkoutOptions.colorOptions.formatting
					carthage.println(formatting.bullets + "No Cartfile.resolved found, updating dependencies")
					return project.updateDependencies(shouldCheckout: options.checkoutAfterUpdate)
				}
				
				if let depsToUpdate = options.dependenciesToUpdate {
					let resolvedCartfileContents = try! String(contentsOfURL: project.resolvedCartfileURL, encoding: NSUTF8StringEncoding)
					let resolvedCartfile = ResolvedCartfile.fromString(resolvedCartfileContents).value!
					let resolvedDependencyNames = Set<String>(resolvedCartfile.dependencies.map { $0.project.name })
					
					for dep in depsToUpdate {
						if !resolvedDependencyNames.contains(dep) {
							return SignalProducer<(), CarthageError>(error:CarthageError.UnresolvedDependency(dep))
						}
					}
				}
				
				if options.checkoutAfterUpdate {
					return project.checkoutResolvedDependencies(options.dependenciesToUpdate)
				} else {
					return .empty
				}
			}
			.then(options.buildProducer)
			.waitOnCommand()
	}
}
