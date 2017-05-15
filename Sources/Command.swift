//
//  Command.swift
//  CommandCougar
//
//  Copyright (c) 2017 Surf & Neptune LLC (http://surfandneptune.com/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation


/// A struct used to describe a command entry for evaluation and help menu
public struct Command: CommandIndexable {
	
	/// A callback type used to notify after evaluation
	public typealias Callback = ((CommandEvaluation) throws -> Void)
	
	/// The name of this command
	public var name: String
	
	/// The overview of this command used in the help menu
	public var overview: String
	
	/// The options this command is allowed to take in
	public var options: [Option]
	
	/// The parameters this command is allowd to take in
	public var parameters: [Parameter]
	
	/// The subCommands this parameter is allowd to take in
	public var subCommands: [Command]
	
	/// The callback used by PerformCallbacks when this command is evaulated
	public var callback: Callback?
	
	/// The useage generated by this command
	public var usage: String
	
	/// The minimum number of parameters allowed
	internal var minParameterCount: Int {
		return parameters.filter{ $0.isRequired }.count
	}
	
	/// The maximum number of parameters allowed
	internal var maxParameterCount: Int {
		return parameters.count
	}
	
	/// The helpText that is generated by this command
	public var helpText: String {
		let commandHelp = subCommands
			.map {
				"\($0.name.padding(toLength: 30, withPad: " ", startingAt: 0))" +
				"\($0.overview)"
			}
			.reduce("SUBCOMMANDS:", { "\($0)\n   \($1)" })
		let optionHelp =
			(options)
				.map { $0.helpText }
				.reduce("OPTIONS:", { "\($0)\n   \($1)" })
		
		return "OVERVIEW: \(overview)\n\nUSAGE: \(usage)\n\n\(commandHelp)\n\n\(optionHelp)"
	}
	
	/// Command Init.  This init allows for parameters and not
	/// subcommands since a command can not have both subcommands and parameters
	///
	/// - Parameters:
	///   - name: The name of this command
	///   - overview: The overview used in the help menu
	///   - callback: The callback which is called when the command evaluates to true
	///   - options: Possible options this command is allow to take in
	///   - parameters: Possible parameters this command is allowed to take in
	public init(
		name: String,
		overview: String,
		callback: Callback?,
		options: [Option],
		parameters: [Parameter]) {
		self.name = name
		self.overview = overview
		self.callback = callback
		self.options = options + [Option.help]
		self.subCommands = []
		self.parameters = parameters
		self.usage = "\(name) [options] [parameters]"
	}
	
	/// Command Init.  This init allows for subCommands and not
	/// parameters since a command can not have both subcommands and parameters
	///
	/// - Parameters:
	///   - name: The name of this command
	///   - overview: The overview used in the help menu
	///   - callback: The callback which is called when the command evaluates to true
	///   - options: Possible options this command is allow to take in
	///   - subCommands: Possible subCommands this command is allowed to take in
	public init(
		name: String,
		overview: String,
		callback: Callback?,
		options: [Option],
		subCommands: [Command]) {
		self.name = name
		self.overview = overview
		self.callback = callback
		self.options = options + [Option.help]
		self.parameters = []
		self.subCommands = subCommands
		self.usage = "\(name) [options] subcommand"
	}
	
	/// Ensures that the Command structure is valid
	///
	/// - Throws: Error if the Command structure is not valid
	public func validate() throws {
		//  A command can not have both subcommands and parameters
		if parameters.count > 0 && subCommands.count > 0 {
			throw CommandCougar.Errors.validate("A command can not have both subcommands and parameters.")
		}
		
		// Subcommand names must be unique
		let subCommandNames = subCommands.map { $0.name }
		if subCommandNames.count != Set(subCommandNames).count {
			throw CommandCougar.Errors.validate("Duplicate subCommand(s) for command \(name). Subcommand names must be unique.")
		}
		
		// Option flags must be unique i.e. they can't have the same shortNames or longNames
		let shorts = options.flatMap ({ $0.flag.shortName })
		let longs = options.flatMap ({ $0.flag.longName })
		if shorts.count != Set(shorts).count, longs.count != Set(longs).count {
			throw CommandCougar.Errors.validate("Duplicate option flag(s) for command \(name). Option flags must be unique.")
		}
	}
	
	/// Strip the first arg and subevaluate
	///
	/// - Parameter args: The command line arugments usually from CommandLine.arguments
	/// - Returns: A evaulated command.  The evaluation contains a subevaluation for any subCommand parsed
	/// - Throws: Error if arguments is malformed or this command does not support option / parameter
	public func evaluate(arguments: [String]) throws -> CommandEvaluation {
		return try subEvaluate(arguments:arguments.dropFirst().map { $0 })
	}
	
	/// Evaluates this command and all subcommands againts a set of arguments.
	/// This will generate a evaluation filled out with the options and parameters
	/// passed into each
	///
	/// - Parameter args: The command line arugments usually from CommandLine.arguments
	/// - Returns: A evaulated command.  The evaluation contains a subevaluation for any subCommand parsed
	/// - Throws: Error if arguments is malformed or this command does not support option / parameter
	private func subEvaluate(arguments: [String]) throws -> CommandEvaluation {
		
		guard arguments.count > 0 else { throw CommandCougar.Errors.parse("No arguments given.") }
		
		try validate()
		
		var evaluation = CommandEvaluation(describer: self)
		var argsList = arguments
		
		argWalk: while !argsList.isEmpty {
			let next = argsList.removeFirst()
			
			if let subCommand = subCommands.first(where: { $0.name == next }) {
				evaluation.subEvaluation = try subCommand.subEvaluate(arguments: argsList)
				try evaluation.validate()
				return evaluation
				
			}
			else if
				let option = OptionEvaluation(string: next) {
				
				if option.flag == "help" {
					print(helpText)
					return evaluation
				}
				
				evaluation.options.append(option)
			}
			else {
				evaluation.parameters.append(next)
			}
			
		}
		
		try evaluation.validate()
		
		return evaluation
	}
	
	/// A subscript to access this commands subcommand by name
	///
	/// - Parameter commandName: The name of the subcommand
	public subscript(subCommand: String) -> Command? {
		get {
			return subCommands[subCommand]
		} set {
			subCommands[subCommand] = newValue
		}
	}
}
