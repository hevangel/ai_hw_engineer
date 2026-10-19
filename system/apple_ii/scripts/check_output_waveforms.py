#!/usr/bin/env python3
"""Independent impedance-domain oracle for the physical output networks.

Circuit topology: original Red Book S-10/S-11 and manifest net audit.
This uses complex impedances/Fourier synthesis, not the RTL time-step solver.
The reduced device parameters are explicit assumptions in spec/analog.md.
"""
import cmath
import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check_tank():
    rows = list(csv.reader((ROOT/'work/output_tank.csv').open()))
    assert len(rows) == 7000, 'Incomplete tank trace'
    # Q3 remains conducting during this all-white test. Its small-signal
    # base impedance includes R7, R8 and the beta-reflected emitter load.
    base_g = 1/1500 + 1/2000 + 1/(200*101)
    base_z = 1/base_g
    base_source = (3.5/1500 + 3.5/2000 + .6/(200*101))/base_g
    tank_dc_z = 1/(1/10 + 1/(2700+base_z))
    dc = (1.85/1000+base_source/(2700+base_z))*tank_dc_z/(1+tank_dc_z/1000)
    omega = 2*math.pi/(279.368e-9)
    errors = []
    for t, _, observed, voltage in rows[-2000:]:
        phase = (float(t)-60000)*1e-9
        expected = dc
        # Source is a low-first square wave. Odd harmonics flow through
        # the parallel L/C/base network in series with R5.
        for n in range(1, 32, 2):
            z = 1/(1/(10+1j*n*omega*27e-6) +
                   1j*n*omega*73.216e-12 + 1/(2700+base_z))
            transfer = z/(1000+z)
            expected -= 2*3.3/(math.pi*n)*(transfer*cmath.exp(1j*n*omega*phase)).imag
        assert float(voltage) > 1, 'Unexpected Q3 cutoff invalidates linear oracle'
        errors.append(float(observed)-expected)
    rms = math.sqrt(sum(e*e for e in errors)/len(errors))
    # Includes 2 ns digital-edge quantization and discarded higher harmonics.
    assert rms < .04 and max(map(abs, errors)) < .15, f'Tank impedance response RMS={rms}'
    print(f'PASS independent L1/Cap2/CT3 Fourier response: RMS error {rms:.6f} V')


def check_speaker():
    rows = [tuple(map(float, row)) for row in
            csv.reader((ROOT/'work/output_speaker.csv').open())]
    assert len(rows) == 2000, 'Incomplete speaker trace'
    worst = 0.0
    for previous, now in zip(rows[2:], rows[3:]):
        dt = (now[0]-previous[0])*1e-9
        # Load alone obeys V=L*dI/dt + R*I regardless of Q4's branch.
        residual = (now[1]+previous[1])/2 - 200e-6*(now[2]-previous[2])/dt - \
            8*(now[2]+previous[2])/2
        worst = max(worst, abs(residual))
    # CSV rounds to 1 uA: derivative quantization contributes up to 2 mV.
    assert worst < .003, f'Speaker winding voltage/current inconsistent: {worst}'
    print(f'PASS independent speaker winding law: max residual {worst:.6f} V')


if __name__ == '__main__':
    check_tank()
    check_speaker()
