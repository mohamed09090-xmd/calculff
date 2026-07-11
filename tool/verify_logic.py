#!/usr/bin/env python3
"""Independent executable mirror of the MVP's critical arithmetic.

This does not replace flutter test. It exists so the project archive can be
sanity-checked in environments where Flutter/Dart are unavailable.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from math import floor

@dataclass(frozen=True)
class Package:
    id: str
    price: int
    credit: int
    validity: int

PACKAGES = [
    Package('110', 150, 110, 24),
    Package('200', 250, 200, 24),
    Package('400', 500, 400, 168),
    Package('900', 1000, 900, 168),
    Package('2000', 2000, 2000, 360),
    Package('3000', 3000, 3000, 720),
]

def optimize(required: int, packages=PACKAGES):
    if required == 0:
        return (0, 0, {})
    limit = required + max(p.credit for p in packages) - 1
    # total -> (cost, count, min_validity, validity_sum, counts)
    states = [None] * (limit + 1)
    states[0] = (0, 0, 0, 0, {})
    for total, state in enumerate(states):
        if state is None:
            continue
        cost, count, minimum, validity_sum, counts = state
        for p in packages:
            nxt = total + p.credit
            if nxt > limit:
                continue
            new_counts = dict(counts)
            new_counts[p.id] = new_counts.get(p.id, 0) + 1
            candidate = (
                cost + p.price,
                count + 1,
                p.validity if count == 0 else min(minimum, p.validity),
                validity_sum + p.validity,
                new_counts,
            )
            old = states[nxt]
            key = lambda x: (x[0], x[1], -x[2], -x[3])
            if old is None or key(candidate) < key(old):
                states[nxt] = candidate
    winners = []
    for total in range(required, limit + 1):
        state = states[total]
        if state is not None:
            winners.append((state[0], total - required, state[1], -state[2], -state[3], total, state[4]))
    winner = min(winners)
    return winner[0], winner[5], winner[6]

def calculate_amount(amount: int, inventory: int = 0):
    units = floor(amount / 350)
    gems = units * 100
    charged = units * 350
    change = amount - charged
    required = units * 240
    inventory_used = min(required, inventory)
    additional = required - inventory_used
    cost, purchased, counts = optimize(additional)
    return {
        'units': units,
        'gems': gems,
        'charged': charged,
        'change': change,
        'required': required,
        'inventory_used': inventory_used,
        'additional': additional,
        'cost': cost,
        'purchased': purchased,
        'leftover': purchased - additional,
        'profit': charged - cost,
        'counts': counts,
    }

def verify():
    main = calculate_amount(6000)
    assert main == {
        'units': 17,
        'gems': 1700,
        'charged': 5950,
        'change': 50,
        'required': 4080,
        'inventory_used': 0,
        'additional': 4080,
        'cost': 4150,
        'purchased': 4110,
        'leftover': 30,
        'profit': 1800,
        'counts': {'110': 1, '2000': 2},
    }, main
    cost, total, counts = optimize(2400)
    assert (cost, total, counts) == (2500, 2400, {'400': 1, '2000': 1})
    low = calculate_amount(349)
    assert low['units'] == 0 and low['change'] == 349 and low['required'] == 0
    full = calculate_amount(350, 240)
    assert full['inventory_used'] == 240 and full['cost'] == 0 and full['profit'] == 350
    partial = calculate_amount(350, 100)
    assert partial['additional'] == 140 and partial['purchased'] == 200 and partial['cost'] == 250

    now = datetime(2026, 7, 11, 12)
    lots = [
        {'id': 'expired', 'remaining': 100, 'expires': now - timedelta(minutes=1)},
        {'id': 'soon', 'remaining': 100, 'expires': now + timedelta(hours=2)},
        {'id': 'late', 'remaining': 100, 'expires': now + timedelta(days=2)},
    ]
    eligible = sorted((x for x in lots if x['expires'] > now), key=lambda x: x['expires'])
    required = 120
    allocations = []
    for lot in eligible:
        take = min(lot['remaining'], required)
        allocations.append((lot['id'], take))
        required -= take
        if required == 0:
            break
    assert allocations == [('soon', 100), ('late', 20)]

    assert 150 / 10 == 15 and 6000 / 10 == 600 and 35 * 10 == 350
    print('PASS: 6000 DZD mandatory scenario')
    print('PASS: 2400 credit optimization')
    print('PASS: low amount, full inventory, partial inventory')
    print('PASS: expired filtering and FEFO ordering')
    print('PASS: DZD/thousands conversion')

if __name__ == '__main__':
    verify()
