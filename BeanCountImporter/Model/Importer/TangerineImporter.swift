//
//  TangerineImporter.swift
//  BeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

class TangerineImporter: CSVImporter {

    private static let date = "Date"
    private static let name = "Name"
    private static let memo = "Memo"
    private static let amount = "Amount"

    static let header = [date, "Transaction", name, memo, amount]

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        return dateFormatter
    }()

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        var description = ""
        var payee = ""
        if csvReader[Self.name]! == "Interest Paid" {
            payee = "Tangerine"
        } else {
            description = csvReader[Self.memo]!
        }
        let amount = Decimal(string: csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        return CSVLine(date: date, description: description, amount: amount, payee: payee, price: nil)
    }

}