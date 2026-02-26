#!/usr/bin/env python3
"""Output truly random numbers in the inclusive range 1..108."""

from __future__ import annotations

import argparse
import secrets


def random_1_to_108() -> int:
    """Return a cryptographically secure random integer from 1 to 108."""
    return secrets.randbelow(108) + 1


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Output truly random number(s) in the inclusive range 1..108.",
    )
    parser.add_argument(
        "-n",
        "--count",
        type=int,
        default=1,
        help="how many random numbers to output (default: 1)",
    )
    args = parser.parse_args()

    if args.count < 1:
        raise SystemExit("--count must be at least 1")

    for _ in range(args.count):
        print(random_1_to_108())


if __name__ == "__main__":
    main()
