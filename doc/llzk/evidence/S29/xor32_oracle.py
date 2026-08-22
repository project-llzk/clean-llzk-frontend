#!/usr/bin/env python3
"""Independent Xor32 promotion oracle; imports neither Clean nor LLZK."""

P_BABYBEAR = 2_013_265_921

SPEC_CASES = (
    ("spec_zero", (0, 0, 0, 0), (0, 0, 0, 0)),
    ("spec_all_ones", (255, 255, 255, 255), (0, 0, 0, 0)),
    ("spec_high_bit", (128, 128, 128, 128), (0, 1, 127, 255)),
    ("spec_alternating", (170, 85, 170, 85), (85, 170, 85, 170)),
    ("spec_equal", (0, 1, 128, 255), (0, 1, 128, 255)),
    ("spec_lane_markers", (1, 2, 4, 8), (16, 32, 64, 128)),
    ("spec_mixed_word", (18, 52, 86, 120), (135, 101, 67, 33)),
)

COMPUTE_CASES = (
    ("compute_x_wide", (256, 257, 511, 65535), (1, 2, 128, 170)),
    ("compute_y_wide", (0, 255, 85, 170), (256, 257, 511, 65535)),
    (
        "compute_both_wide",
        (P_BABYBEAR - 1, 65536, 1000, 65706),
        (257, 511, 65535, P_BABYBEAR - 1),
    ),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def pack_le32(limbs: tuple[int, int, int, int]) -> int:
    require(len(limbs) == 4, "spec input does not have four limbs")
    require(all(0 <= limb < 256 for limb in limbs), "spec input is not four bytes")
    return sum(limb << (8 * index) for index, limb in enumerate(limbs))


def split_le32(word: int) -> tuple[int, int, int, int]:
    require(0 <= word < 2**32, "XOR result is not a 32-bit word")
    return tuple((word >> (8 * index)) & 0xFF for index in range(4))


def render(name: str, x: tuple[int, ...], y: tuple[int, ...], scope: str,
           outputs: tuple[int, ...], raw: tuple[int, ...] | None = None) -> None:
    print(name)
    print(f"  scope: {scope}")
    print(f"  inputs: {[*x, *y]}")
    print(f"  outputs: {list(outputs)}")
    if raw is not None:
        print(f"  old raw XOR after Babybear reduction: {list(raw)}")


def main() -> None:
    require(len(SPEC_CASES) == 7, "oracle must contain exactly seven spec cases")
    require(len(COMPUTE_CASES) == 3, "oracle must contain exactly three compute cases")
    names = [name for name, _, _ in (*SPEC_CASES, *COMPUTE_CASES)]
    require(len(names) == len(set(names)), "oracle case names are not unique")
    for name, x, y in SPEC_CASES:
        x_word = pack_le32(x)
        y_word = pack_le32(y)
        output_word = x_word ^ y_word
        outputs = split_le32(output_word)
        render(name, x, y, "spec", outputs)
        print(f"  words: 0x{x_word:08x} XOR 0x{y_word:08x} = 0x{output_word:08x}")
        print("  split: out_i = (output_word >> (8*i)) & 255")

    for name, x, y in COMPUTE_CASES:
        require(len(x) == 4 and len(y) == 4, f"{name}: expected four limbs per operand")
        require(
            all(0 <= value < P_BABYBEAR for value in (*x, *y)),
            f"{name}: input is not a canonical Babybear representative",
        )
        outputs = tuple((left & 0xFF) ^ (right & 0xFF) for left, right in zip(x, y))
        raw = tuple((left ^ right) % P_BABYBEAR for left, right in zip(x, y))
        require(
            all(output != old for output, old in zip(outputs, raw)),
            f"{name}: a lane does not distinguish narrowing from raw XOR",
        )
        render(name, x, y, "computeOnly", outputs, raw)
        print("  rule: out_i = (x_i & 0xff) XOR (y_i & 0xff)")


if __name__ == "__main__":
    main()
