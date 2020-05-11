//
//  FileImporter.swift
//  BeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

enum FileImporterManager {

    static var importers: [FileImporter.Type] {
        CSVImporterManager.importers
    }

    static func new(url: URL?, accountName: String, commoditySymbol: String) -> FileImporter? {
        CSVImporterManager.new(url: url, accountName: accountName, commoditySymbol: commoditySymbol)
    }

}

struct ImportedTransaction {

    let transaction: Transaction
    let originalDescription: String

}

protocol FileImporter: Importer {

    var account: Account { get }

    func loadFile()
    func parseLineIntoTransaction() -> ImportedTransaction?

}