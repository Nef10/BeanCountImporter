//
//  CSVImporter.swift
//  BeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import CSV
import Foundation
import SwiftBeanCountModel

class CSVImporter {

    struct CSVLine {
        let date: Date
        let description: String
        let amount: Decimal
        let payee: String
    }

    let csvReader: CSVReader
    private let accountName: String
    private let commoditySymbol: String

    static private let unknownAccountName = "TODO"

    static private let payees = [
        "Safeway",
        "Jugo Juice",
        "Starbucks",
        "Ebiten",
        "Mcdonald's",
        "Tim Horton's",
        "Tim Hortons",
        "Mastercuts",
        "Fresh Bowl",
        "Donair Stop",
        "Freedom Mobile",
        "Subway",
        "Brooklyn Pizza",
        "Sushi Aji",
        "Cineplex",
        "Rodney's Oyster House",
        "The Greek By Anatoli",
        "Lickerish",
        "Delicious Pho",
        "Red Card Sports Bar",
        ]

    static private let naming = [
        "Bean Around The": "Bean around the World",
        "Bean Around The World": "Bean around the World",
        "Compass Vending": "Translink",
        "Ikea Richmond": "IKEA",
        "Tacofino Yaleto": "Tacofino",
        "Grounds For App": "Grounds For Appeal",
        "The Greek By An": "The Greek",
        "Phat Sports Bar": "PHAT Sports Bar",
        "A&w": "A&W",
        "A&W Store": "A&W",
        "Yaletown Keg": "The Keg",
        "Square One Insu": "SquareOne",
        "Netflix.Com": "Netflix",
        "Yaletown Brewing Co.": "Yaletown Brewing Company",
        "Real Cdn Superstore": "Real Canadian Superstore",
        "H&M Ca -Metropolis": "H&M",
        "Jugo Juice Broadway St": "Jugo Juice",
        "Dairy Queen Orange Jul": "Orange Julius",
        "Earls Yaletown": "Earls",
        "Earl's Fir Street": "Earls",
        "Broadway & Macdonald": "",
        "Fresh Take Out Japanes": "Fresh Sushi",
        "Nero Belgian Waffle Ba": "Nero",
        "Score On Davie": "Score",
        ]

    static private let accounts = [
        "Safeway": "Expenses:Food:Groceries",
        "Jugo Juice": "Expenses:Food:Snack",
        "Starbucks": "Expenses:Food:Snack",
        "Ebiten": "Expenses:Food:TakeOut",
        "Mcdonald's": "Expenses:Food:FastFood",
        "Tim Hortons": "Expenses:Food:Snack",
        "Tim Horton's": "Expenses:Food:Snack",
        "Mastercuts": "Expenses:Living:Services",
        "Fresh Bowl": "Expenses:Food:TakeOut",
        "Bean around the World": "Expenses:Food:TakeOut",
        "Tacofino": "Expenses:Food:TakeOut",
        "Grounds For Appeal": "Expenses:Food:TakeOut",
        "PHAT Sports Bar": "Expenses:Food:TakeOut",
        "A&W": "Expenses:Food:FastFood",
        "Donair Stop": "Expenses:Food:TakeOut",
        "RBC": "Expenses:FinancialInstitutions",
        "Freedom Mobile": "Expenses:Communication:MobilePhone:Contract",
        "SquareOne": "Expenses:Insurance:Tenant:SquareOne",
        "Netflix": "Expenses:Leisure:Entertainment:Streaming",
        "Brooklyn Pizza": "Expenses:Food:TakeOut",
        "Sushi Aji": "Expenses:Food:EatingOut",
        "Cineplex": "Expenses:Leisure:Entertainment:Cinema",
        "Tangerine": "Income:FinancialInstitutions:Interests",
        "H&M": "Expenses:Living:Clothes:Clothes",
        "Rodney's Oyster House": "Expenses:Food:EatingOut",
        "Lickerish": "Expenses:Leisure:Entertainment:Party",
        "Delicious Pho": "Expenses:Food:EatingOut",
        "Score": "Expenses:Food:EatingOut",
        "Orange Julius": "Expenses:Food:Snack",
        ]

    static private let regexe: [NSRegularExpression] = {
        [ // swiftlint:disable force_try
            try! NSRegularExpression(pattern: "(C-)?IDP PURCHASE( )?-( )?[0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "VISA DEBIT (PUR|REF)-[0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "WWWINTERAC PUR [0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "INTERAC E-TRF- [0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "[0-9]* ~ Internet Withdrawal", options: []),
            try! NSRegularExpression(pattern: "[^ ]*  BC  CA", options: []),
            try! NSRegularExpression(pattern: "#( )?[0-9]{1,5}", options: []),

        ] // swiftlint:enable force_try
    }()

    init(csvReader: CSVReader, accountName: String, commoditySymbol: String) {
        self.csvReader = csvReader
        self.accountName = accountName
        self.commoditySymbol = commoditySymbol
    }

    func parse() -> Ledger {
        let ledger = Ledger()
        let account = Account(name: accountName)
        let unknownAccount = Account(name: CSVImporter.unknownAccountName)
        let commodity = Commodity(symbol: commoditySymbol)
        while csvReader.next() != nil {
            let data = parseLine()
            var description = data.description
            var payee = data.payee
            for regex in CSVImporter.regexe {
                description = regex.stringByReplacingMatches(in: description,
                                                             options: .withoutAnchoringBounds,
                                                             range: NSRange(description.startIndex..., in: description),
                                                             withTemplate: "")
            }
            description = description.replacingOccurrences(of: "&amp;", with: "&")
            description = description.trimmingCharacters(in: .whitespaces)
            description = description.capitalized
            if let naming = CSVImporter.naming[description] {
                payee = naming
                description = ""
            } else if CSVImporter.payees.contains(description) {
                payee = description
                description = ""
            }
            let transactionMetaData = TransactionMetaData(date: data.date, payee: payee, narration: description, flag: .complete, tags: [])
            let transaction = Transaction(metaData: transactionMetaData)
            let amount = Amount(number: data.amount, commodity: commodity, decimalDigits: 2)
            let accountPosting = Posting(account: account, amount: amount, transaction: transaction)
            transaction.postings.append(accountPosting)
            let categoryAmount = Amount(number: -data.amount, commodity: commodity, decimalDigits: 2)
            var categoryAccount = unknownAccount
            if let accountName = CSVImporter.accounts[payee] {
                categoryAccount = Account(name: accountName)
            }
            let categoryPosting = Posting(account: categoryAccount, amount: categoryAmount, transaction: transaction)
            transaction.postings.append(categoryPosting)
            ledger.transactions.append(transaction)
        }
        return ledger
    }

    func parseLine() -> CSVLine {
        fatalError("Must Override")
    }

    static func new(url: URL?, accountName: String, commoditySymbol: String) -> CSVImporter? {
        guard let url = url, let csvReader = openFile(url), let headerRow = csvReader.headerRow else {
            return nil
        }
        if headerRow == RBCImporter.header {
            return RBCImporter(csvReader: csvReader, accountName: accountName, commoditySymbol: commoditySymbol)

        } else if headerRow == TangerineImporter.header {
            return TangerineImporter(csvReader: csvReader, accountName: accountName, commoditySymbol: commoditySymbol)
        }
        return nil
    }

    private static func openFile(_ url: URL) -> CSVReader? {
        let inputStream = InputStream(url: url)
        guard let input = inputStream else {
            return nil
        }
        do {
            return try CSVReader(stream: input, hasHeaderRow: true, trimFields: true)
        } catch {
            return nil
        }
    }

}
