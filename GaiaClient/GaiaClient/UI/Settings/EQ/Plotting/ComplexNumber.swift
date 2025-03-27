//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public struct ComplexNumber {
    let real: Double
    let imaginary: Double

    public var radiusSquare: Double { return real * real + imaginary * imaginary }
    public var radius: Double { return sqrt(radiusSquare) }
    public var arg: Double { return atan2(imaginary, real) }
}

public extension ComplexNumber {
    init (real: Double) {
        self.init (real: real, imaginary: 0)
    }

    func add(_ otherNumber: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: real + otherNumber.real, imaginary: imaginary + otherNumber.imaginary)
    }

    func subtract(_ otherNumber: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: real - otherNumber.real, imaginary: imaginary - otherNumber.imaginary)
    }

    func multiply(_ otherNumber: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(real: real * otherNumber.real - imaginary * otherNumber.imaginary,
                             imaginary: real * otherNumber.imaginary + imaginary * otherNumber.real)
    }

    func divide(_ otherNumber: Double) -> ComplexNumber {
        return ComplexNumber(real: real / otherNumber, imaginary: imaginary / otherNumber)
    }

    func divide(_ otherNumber: ComplexNumber) -> ComplexNumber {
        return self.multiply((otherNumber.conjugate().divide(otherNumber.radiusSquare)))
    }

    func conjugate() -> ComplexNumber {
        return ComplexNumber(real: real, imaginary: -imaginary)
    }
}

public func + (num1: ComplexNumber, num2: ComplexNumber) -> ComplexNumber {
    return num1.add(num2)
}

public func - (num1: ComplexNumber, num2: ComplexNumber) -> ComplexNumber {
    return num1.subtract(num2)
}

public func * (num1: ComplexNumber, num2: ComplexNumber) -> ComplexNumber {
    return num1.multiply(num2)
}

public func / (num1: ComplexNumber, num2: ComplexNumber) -> ComplexNumber {
    return num1.divide(num2)
}

