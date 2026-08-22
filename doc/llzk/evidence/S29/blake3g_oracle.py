#!/usr/bin/env python3
"""Independent BLAKE3.G 0/1/2/3 oracle; imports neither Clean nor LLZK.

The operation order is transcribed from the official BLAKE3 reference
implementation's ``g`` function at the immutable revision below.  The six
updated-word checkpoints were computed independently of this repository and
are kept literal so an implementation or endian mistake fails closed.
"""

REFERENCE_REPOSITORY = "https://github.com/BLAKE3-team/BLAKE3"
REFERENCE_COMMIT = "f3149ec5bb5449af877ba20377a11008ff499fa2"
REFERENCE_PATH = "reference_impl/reference_impl.rs:41-50"

U32_MODULUS = 1 << 32
U32_MASK = U32_MODULUS - 1


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def pack_le32(limbs: tuple[int, ...]) -> int:
    require(len(limbs) == 4, "a word does not have four limbs")
    require(all(0 <= limb < 256 for limb in limbs), "a word limb is not a byte")
    manual = sum(limb << (8 * index) for index, limb in enumerate(limbs))
    library = int.from_bytes(bytes(limbs), byteorder="little")
    require(manual == library, "manual and stdlib little-endian packing disagree")
    return manual


def split_le32(word: int) -> tuple[int, int, int, int]:
    require(0 <= word < U32_MODULUS, "a result is not a uint32")
    manual = tuple((word >> (8 * index)) & 0xFF for index in range(4))
    library = tuple(word.to_bytes(4, byteorder="little"))
    require(manual == library, "manual and stdlib little-endian splitting disagree")
    return manual


def add32(left: int, right: int) -> tuple[int, bool]:
    total = left + right
    return total & U32_MASK, total >= U32_MODULUS


def ror32(word: int, distance: int) -> int:
    require(0 < distance < 32, "rotation distance is outside 1..31")
    require(0 <= word < U32_MODULUS, "rotation operand is not a uint32")
    return ((word >> distance) | (word << (32 - distance))) & U32_MASK


def g_0_1_2_3(state: tuple[int, ...], x: int, y: int) \
        -> tuple[tuple[int, ...], tuple[bool, ...]]:
    require(len(state) == 16, "BLAKE3 state does not have sixteen words")
    require(all(0 <= word < U32_MODULUS for word in (*state, x, y)),
            "BLAKE3 input is not a uint32")
    result = list(state)
    carries: list[bool] = []

    result[0], carry = add32(result[0], result[1])
    carries.append(carry)
    result[0], carry = add32(result[0], x)
    carries.append(carry)
    result[3] = ror32(result[3] ^ result[0], 16)
    result[2], carry = add32(result[2], result[3])
    carries.append(carry)
    result[1] = ror32(result[1] ^ result[2], 12)
    result[0], carry = add32(result[0], result[1])
    carries.append(carry)
    result[0], carry = add32(result[0], y)
    carries.append(carry)
    result[3] = ror32(result[3] ^ result[0], 8)
    result[2], carry = add32(result[2], result[3])
    carries.append(carry)
    result[1] = ror32(result[1] ^ result[2], 7)

    require(tuple(result[4:]) == state[4:], "G modified a state lane outside 0..3")
    return tuple(result), tuple(carries)


ZERO_STATE = (0,) * 16
MAX_STATE = (U32_MASK,) * 16
ALTERNATING_STATE = tuple(0xAAAAAAAA if index % 2 == 0 else 0x55555555
                          for index in range(16))
CARRY_STATE = (0x80808080, 0x00000001, 0xFFFFFFFE, 0xFFFFFFFF) + (0,) * 12
HIGH_BIT_STATE = (0x80000000, 0x00000000, 0x80000000, 0xFFFFFFFF) + (0,) * 12
MARKER_STATE = (
    0x03020100, 0x07060504, 0x0B0A0908, 0x0F0E0D0C,
    0xD2D1D0CF, 0xD6D5D4D3, 0xDAD9D8D7, 0xDEDDDCDB,
    0xE2E1E0DF, 0xE6E5E4E3, 0xEAE9E8E7, 0xEEEDECEB,
    0xF2F1F0EF, 0xF6F5F4F3, 0xFAF9F8F7, 0xFEFDFCFB,
)

# name, state, x, y, independently fixed updated state indices 0--3
CASES = (
    ("spec_zero", ZERO_STATE, 0x00000000, 0x00000000,
     (0x00000000, 0x00000000, 0x00000000, 0x00000000)),
    ("spec_max_bytes", MAX_STATE, 0xFFFFFFFF, 0xFFFFFFFF,
     (0x000FFFDC, 0x3DB81BE4, 0xDC020DFE, 0xDC000DFF)),
    ("spec_alternating", ALTERNATING_STATE, 0xAAAAAAAA, 0x55555555,
     (0xFFCFFF2D, 0x0D06D045, 0x7CA7DDA9, 0xD2003300)),
    ("spec_carry_heavy", CARRY_STATE, 0xFFFFFFFE, 0x7FFFFFFF,
     (0xF8487885, 0x071B9F7F, 0x7A084784, 0xFA87C807)),
    ("spec_high_bit", HIGH_BIT_STATE, 0x80000000, 0x00000001,
     (0xFFF80000, 0x0301EFF0, 0x7F0007FE, 0xFF0007FF)),
    ("spec_lane_markers", MARKER_STATE, 0x13121110, 0x17161514,
     (0x15B24E69, 0x728767CE, 0xA231C578, 0x7D0FAA5C)),
)


def flatten_words(words: tuple[int, ...]) -> tuple[int, ...]:
    limbs: list[int] = []
    for word in words:
        split = split_le32(word)
        require(pack_le32(split) == word, "split/pack uint32 roundtrip failed")
        limbs.extend(split)
    return tuple(limbs)


def repack_words(limbs: tuple[int, ...]) -> tuple[int, ...]:
    require(len(limbs) % 4 == 0, "flattened limbs do not tile into words")
    return tuple(pack_le32(tuple(limbs[offset:offset + 4]))
                 for offset in range(0, len(limbs), 4))


def render_case(name: str, state: tuple[int, ...], x: int, y: int,
                expected_updated: tuple[int, ...]) -> None:
    result, carries = g_0_1_2_3(state, x, y)
    require(result[:4] == expected_updated, f"{name}: updated-word checkpoint mismatch")
    inputs = flatten_words((*state, x, y))
    outputs = flatten_words(result)
    require(len(inputs) == 72, f"{name}: input does not have 72 byte limbs")
    require(len(outputs) == 64, f"{name}: output does not have 64 byte limbs")
    require(all(0 <= limb < 256 for limb in (*inputs, *outputs)),
            f"{name}: a flattened limb is not a byte")
    require(repack_words(inputs) == (*state, x, y),
            f"{name}: flattened inputs do not reconstruct the input words")
    require(repack_words(outputs) == result,
            f"{name}: flattened outputs do not reconstruct the result words")
    require(all(pack_le32(split_le32(word)) == word for word in expected_updated),
            f"{name}: an updated-word checkpoint does not roundtrip")
    require(outputs[16:] == inputs[16:64], f"{name}: unchanged lane bytes drifted")

    print(name)
    print("  scope: spec")
    print("  input words: " + " ".join(f"{word:08x}" for word in (*state, x, y)))
    print(f"  input bytes: {list(inputs)}")
    print("  output words: " + " ".join(f"{word:08x}" for word in result))
    print(f"  output bytes: {list(outputs)}")
    print("  binary-add carries: " + "".join("1" if carry else "0" for carry in carries))
    print("  conversion: limb_i = (word >> (8*i)) & 255, i = 0..3")

    if name == "spec_carry_heavy":
        require(carries == (False, True, True, True, False, True),
                "carry-heavy row no longer wraps the intended four binary additions")
    if name == "spec_lane_markers":
        require(len(set(outputs)) == 64, "marker outputs are not pairwise distinct")
        require(all(output != 0 for output in outputs), "a marker output is zero")


def main() -> None:
    require(len(CASES) == 6, "oracle must contain exactly six cases")
    names = tuple(case[0] for case in CASES)
    require(len(names) == len(set(names)), "oracle case names are not unique")
    print(f"reference repository: {REFERENCE_REPOSITORY}")
    print(f"reference commit: {REFERENCE_COMMIT}")
    print(f"reference definition: {REFERENCE_PATH}")
    for case in CASES:
        render_case(*case)


if __name__ == "__main__":
    main()
