//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import PluginBase

class BiQuadFilter {
    
    public struct PoleZeroPair {
        let pole: [ComplexNumber]
        let zero: [ComplexNumber]
    }

    private struct Coefficients {
        let first: Double
        let second: Double
        let third: Double

        init(_ first: Double, _ second: Double, _ third: Double) {
            self.first = first
            self.second = second
            self.third = third
        }

        init() {
            self.init(0.0, 0.0, 0.0)
        }
    }

    private var coefsA = Coefficients()
    private var coefsB = Coefficients()

    private var m_fc: Double = 48000.0
    public var fc: Double {
        get {
            return m_fc
        }
        set {
            assert(newValue >= 0)        // barf if frequency isn't positive
            m_fc = min(newValue, m_fs / 2)
            calcCoefs()
        }
    }


    private var m_fs: Double = 48000.0
    public var fs: Double {
        get {
            return m_fs
        }
        set {
            assert(newValue >= 0)        // barf if frequency isn't positive
            m_fs = newValue
            m_fc = min(newValue, m_fs / 2)
            calcCoefs()
        }
    }

    public var gain: Double = 1.0 {
        didSet {
            calcCoefs()
        }
    }

    public var q: Double = 0.7 {
        didSet {
            assert (q >= 0)
            calcCoefs()
        }
    }

    public var filterType = FilterType.bypass {
        didSet {
            calcCoefs()
        }
    }

    init() {
        calcBypassFilter()
    }
}

extension BiQuadFilter {
    public func calcCoefs() {
        switch filterType {
        case .bypass:
            calcBypassFilter()
            break
        case .lp1:
            calcLowPassBilin()
            break
        case .hp1:
            calcHighPassBilin()
            break
        case .ap1:
            calcAllPassBilin()
            break
        case .ls1:
            calcLowShelfBilin();
            break
        case .hs1:
            calcHighShelfBilin()
            break
        case .tilt1:
            calcTiltBilin()
            break
        case .lp2:
            calcLowPassBiquad()
            break
        case .hp2:
            calcHighPassBiquad()
            break
        case .ap2:
            calcAllPassBiquad()
            break
        case .ls2:
            calcLowShelfBiquad()
            break
        case .hs2:
            calcHighShelfBiquad()
            break
        case .tilt2:
            calcTiltBiquad()
            break
        case .peq:
            calcParametric()
            break
        }
    }

    private func calcBypassFilter() {
        coefsA = Coefficients(0.0, 0.0, 0.0)
        coefsB = Coefficients(1.0, 0.0, 0.0)
    }

    /// pragma mark 1st order filter coefficient calculation routines

    private func calcLowPassBilin() {
        //--------------------------------------------------------------------------
        // create coefficients for first order low pass bilinear section
        // Filter only uses biquadratic sections so set unused coefficients to zero
        //
        // laplace transform w/(s+w)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let denom = wd + 1.0

        coefsA = Coefficients(0.0, (wd - 1.0) / denom, 0.0)
        coefsB = Coefficients(wd / denom, wd / denom, 0.0)
    }

    private func calcHighPassBilin() {
        //--------------------------------------------------------------------------
        // create coefficients for first order low pass bilinear section
        // Filter only uses biquadratic sections so set unused coefficients to zero
        //
        // laplace transform s/(s+w)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let denom = wd + 1.0

        coefsA = Coefficients(0.0, (wd - 1.0) / denom, 0.0)
        coefsB = Coefficients(1.0 / denom, -1.0 / denom, 0.0)
    }

    private func calcAllPassBilin() {
        //--------------------------------------------------------------------------
        // create coefficients for first order all pass bilinear section
        // Filter only uses biquadratic sections so set unused coefficients to zero
        //
        // laplace transform (s-w)/(s+w)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let denom = wd + 1.0

        coefsA = Coefficients(0.0, (wd - 1.0) / denom, 0.0)
        coefsB = Coefficients((1.0 - wd) / denom, -1.0, 0.0)
    }

    private func calcLowShelfBilin() {
        //--------------------------------------------------------------------------
        // create coefficients for first order low frequency shelf bilinear section
        // Filter only uses biquadratic sections so set unused coefficients to zero
        //
        // laplace transform (s-w1)/(s+w2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let wd1 = wd * pow(10, (gain / 40))
        let wd2 = wd / pow(10, (gain / 40))
        let denom = wd2 + 1.0

        coefsA = Coefficients(0.0, (wd2 - 1.0) / denom, 0.0)
        coefsB = Coefficients((wd1 + 1.0) / denom, (wd1 - 1.0) / denom, 0.0)
    }

    private func calcHighShelfBilin() {
        //--------------------------------------------------------------------------
        // create coefficients for first order high frequency shelf bilinear section
        // Filter only uses biquadratic sections so set unused coefficients to zero
        //
        // laplace transform g*(s-w1)/(s+w2)
        //--------------------------------------------------------------------------
		let wd = tan(Double.pi * m_fc / m_fs)
        let wd1 = wd / pow(10, (gain / 40))
        let wd2 = wd * pow(10, (gain / 40))
        let denom = wd2 + 1.0

        coefsA = Coefficients(0.0,
                              (wd2 - 1.0) / denom,
                              0.0)
        coefsB = Coefficients(pow(10, (gain / 20)) * (wd1 + 1.0) / denom,
                              pow(10, (gain / 20)) * (wd1 - 1.0) / denom,
                              0.0)
    }

    private func calcTiltBilin() {
        //--------------------------------------------------------------------------
        // create coefficients for first order tilt bilinear section
        // Filter only uses biquadratic sections so set unused coefficients to zero
        //
        // laplace transform g*(s-w1)/(s+w2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let wd1 = wd / pow(10, (gain / 40))
        let wd2 = wd * pow(10, (gain / 40))
        let denom = wd2 + 1.0

        coefsA = Coefficients(0.0, (wd2 - 1.0) / denom, 0.0)
        coefsB = Coefficients(pow(10, (gain / 40)) * (wd1 + 1.0) / denom,
                              pow(10, (gain / 40)) * (wd1 - 1.0) / denom,
                              0.0)
    }


/// region 2nd order filter coefficient calculation routines

    //--------------------------------------------------------------------------
    private func calcLowPassBiquad() {
        //--------------------------------------------------------------------------
        // create coefficients for second order low pass biquadratic section
        //
        // laplace transform w^2/(s^2+sw/q+w^2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let denom = wd * wd + wd / q + 1.0

        coefsA = Coefficients(0.0,
                              (2 * wd * wd - 2.0) / denom,
                              (wd * wd - wd / q + 1.0) / denom)

        coefsB = Coefficients(wd * wd / denom,
                              2.0 * wd * wd / denom,
                              wd * wd / denom)
    }

    private func calcHighPassBiquad() {
        //--------------------------------------------------------------------------
        // create coefficients for second order high pass biquadratic section
        //
        // laplace transform s^2/(s^2+sw/q+w^2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let denom = wd * wd + wd / q + 1.0

        coefsA = Coefficients(0.0,
                              (2 * wd * wd - 2.0) / denom,
                              (wd * wd - wd / q + 1.0) / denom)

        coefsB = Coefficients(1.0 / denom,
                              -2.0 / denom,
                              1.0 / denom)
    }

    private func calcAllPassBiquad() {
        //--------------------------------------------------------------------------
        // create coefficients for second order all pass biquadratic section
        //
        // laplace transform (s^2-sw/q+w^2)/(s^2+sw/q+w^2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let denom = wd * wd + wd / q + 1.0

        coefsA = Coefficients(0.0,
                              (2 * wd * wd - 2.0) / denom,
                              (wd * wd - wd / q + 1.0) / denom)

        coefsB = Coefficients((wd * wd - wd / q + 1.0) / denom,
                              (2.0 * wd * wd - 2.0) / denom,
                              1.0)
    }

    private func calcLowShelfBiquad() {
        //--------------------------------------------------------------------------
        // create coefficients for second order low shelf biquadratic section
        //
        // laplace transform (s^2+sw1/q+w1^2)/(s^2+sw2/q+w2^2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let wd1 = wd * pow(10, (gain / 80))
        let wd2 = wd / pow(10, (gain / 80))
        let denom = wd2 * wd2 + wd2 / q + 1.0

        coefsA = Coefficients(0.0,
                              (2.0 * wd2 * wd2 - 2.0) / denom,
                              (wd2 * wd2 - wd2 / q + 1.0) / denom)

        coefsB = Coefficients((wd1 * wd1 + wd1 / q + 1.0) / denom,
                              (2.0 * wd1 * wd1 - 2.0) / denom,
                              (wd1 * wd1 - wd1 / q + 1.0) / denom)
    }

    private func calcHighShelfBiquad() {
        //--------------------------------------------------------------------------
        // create coefficients for second order low shelf biquadratic section
        //
        // laplace transform g*(s^2+sw1/q+w1^2)/(s^2+sw2/q+w2^2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let wd1 = wd / pow(10, (gain / 80))
        let wd2 = wd * pow(10, (gain / 80))
        let denom = wd2 * wd2 + wd2 / q + 1.0

        coefsA = Coefficients(0.0,
                              (2.0 * wd2 * wd2 - 2.0) / denom,
                              (wd2 * wd2 - wd2 / q + 1.0) / denom)

        coefsB = Coefficients(pow(10, (gain / 20)) * (wd1 * wd1 + wd1 / q + 1.0) / denom,
                              pow(10, (gain / 20)) * (2.0 * wd1 * wd1 - 2.0) / denom,
                              pow(10, (gain / 20)) * (wd1 * wd1 - wd1 / q + 1.0) / denom)
    }

    private func calcTiltBiquad() {
        //--------------------------------------------------------------------------
        // create coefficients for second order low shelf biquadratic section
        //
        // laplace transform g*(s^2+sw1/q+w1^2)/(s^2+sw2/q+w2^2)
        //--------------------------------------------------------------------------
        let wd = tan(Double.pi * m_fc / m_fs)
        let wd1 = wd / pow(10, (gain / 80))
        let wd2 = wd * pow(10, (gain / 80))
        let denom = wd2 * wd2 + wd2 / q + 1.0

        coefsA = Coefficients(0.0,
                              (2.0 * wd2 * wd2 - 2.0) / denom,
                              (wd2 * wd2 - wd2 / q + 1.0) / denom)

        coefsB = Coefficients(pow(10, (gain / 40)) * (wd1 * wd1 + wd1 / q + 1.0) / denom,
                              pow(10, (gain / 40)) * (2.0 * wd1 * wd1 - 2.0) / denom,
                              pow(10, (gain / 40)) * (wd1 * wd1 - wd1 / q + 1.0) / denom)
    }

    private func calcParametric() {
        let wd = tan(Double.pi * m_fc / m_fs)
        let a = -1.0 / (2.0 * q) + sqrt(pow(1.0 / (2.0 * q), 2.0) + 1.0)
        let qd = (tan(Double.pi * a * m_fc / m_fs) * tan(Double.pi * m_fc / m_fs)) / (pow(tan(Double.pi * m_fc / m_fs), 2.0) - pow(tan(Double.pi * a * m_fc / m_fs), 2.0))
        let q1 = qd / pow(10.0, gain / 40.0)
        let q2 = qd * pow(10.0, gain / 40.0)
        let denom = wd * wd + wd / q2 + 1.0

        coefsA = Coefficients(0.0,
                              (2 * wd * wd - 2.0) / denom,
                              (wd * wd - wd / q2 + 1.0) / denom)

        coefsB = Coefficients((wd * wd + wd / q1 + 1.0) / denom,
                              (2.0 * wd * wd - 2.0) / denom,
                              (wd * wd - wd / q1 + 1.0) / denom)
    }

///  response calculation routines

    public func calcComplexGain(freq: Double) -> ComplexNumber {
        let num = ComplexNumber (
            real: coefsB.first * cos(0.0) +
                coefsB.second * cos(2 * Double.pi * freq / m_fs) +
                coefsB.third * cos(2 * 2 * Double.pi * freq / m_fs),
            imaginary: -coefsB.first * sin(0.0) -
                coefsB.second * sin(2 * Double.pi * freq / m_fs) -
                coefsB.third * sin(2 * 2 * Double.pi * freq / m_fs)
        )

        let denom = ComplexNumber (
            real: 1.0 * cos(0.0) +
                coefsA.second * cos(2 * Double.pi * freq / m_fs) +
                coefsA.third * cos(2 * 2 * Double.pi * freq / m_fs),
            imaginary: -1.0 * sin(0.0) -
                coefsA.second * sin(2 * Double.pi * freq / m_fs) -
                coefsA.third * sin(2 * 2 * Double.pi * freq / m_fs)
        )

        let gainDiv = denom.radiusSquare
        let gain = ComplexNumber (real: (num.real * denom.real + num.imaginary * denom.imaginary) / gainDiv,
                                  imaginary: (num.imaginary * denom.real - num.real * denom.imaginary) / gainDiv)

        return gain
    }

    public func calcDbGain(freq: Double) -> Double {
        return 20.0 * log10(calcComplexGain(freq: freq).radius)
    }

    public func calcPhase(freq: Double) -> Double {
        return 180.0 * calcComplexGain(freq: freq).arg / Double.pi
    }

    public func calcPoleZero() -> PoleZeroPair {
        var a = coefsB.first
        var b = coefsB.second
        var c = coefsB.third
        var d = (b * b - 4 * a * c) / (4 * a * a)

        var zeros = [ComplexNumber] ()
        var poles = [ComplexNumber] ()

        if c == 0 {
            let zero = ComplexNumber(real: -b / a, imaginary: 0.0)
            zeros.append(zero)
        } else {
            if d > 0 {
                let zero1 = ComplexNumber(real: (-b / (2 * a)) + sqrt(d),
                                          imaginary: 0.0)
                let zero2 = ComplexNumber(real: (-b / (2 * a)) - sqrt(d),
                                          imaginary: 0.0)
				zeros.append(zero1)
                zeros.append(zero2)
            } else {
                let zero1 = ComplexNumber(real: -b / (2 * a),
                                          imaginary: sqrt(-d))
                let zero2 = ComplexNumber(real: -b / (2 * a),
                                          imaginary: -sqrt(-d))
                zeros.append(zero1)
                zeros.append(zero2)
            }
        }

        a = 1.0
        b = coefsA.second
        c = coefsA.third
        d = (b * b - 4 * a * c) / (4 * a * a)

        if c == 0 {
            let pole = ComplexNumber(real: -b / a, imaginary: 0.0)
            poles.append(pole)
        } else {
            if d > 0 {
                let pole1 = ComplexNumber(real: (-b / (2 * a)) + sqrt(d),
                                          imaginary: 0.0)
                let pole2 = ComplexNumber(real: (-b / (2 * a)) - sqrt(d),
                                          imaginary: 0.0)
                poles.append(pole1)
                poles.append(pole2)
            } else {
                let pole1 = ComplexNumber(real: -b / (2 * a),
                                          imaginary: sqrt(-d))
                let pole2 = ComplexNumber(real: -b / (2 * a),
                                          imaginary: -sqrt(-d))
                poles.append(pole1)
                poles.append(pole2)
            }
        }

        return PoleZeroPair(pole: poles, zero: zeros)
    }
}

