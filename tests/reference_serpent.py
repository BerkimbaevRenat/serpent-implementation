"""Small independent Serpent-1 reference, using only the Python standard library.

The API uses byte strings in normal external byte order. Each 32-bit internal
word is little endian; S-boxes act on the four corresponding bits of four words.
This deliberately simple truth-table implementation is a test oracle, not a
constant-time implementation and not intended to protect real secrets.

Algorithm: Anderson, Biham, Knudsen, Serpent: A Proposal for the AES,
https://www.cl.cam.ac.uk/archive/rja14/Papers/serpent.pdf
Its correctness is independently anchored by author-published NESSIE vectors
in kat_vectors.json; run run_tests.py --reference-only to check them.
"""

import struct

SBOXES = (
    (3, 8, 15, 1, 10, 6, 5, 11, 14, 13, 4, 2, 7, 0, 9, 12),
    (15, 12, 2, 7, 9, 0, 5, 10, 1, 11, 14, 8, 6, 13, 3, 4),
    (8, 6, 7, 9, 3, 12, 10, 15, 13, 1, 14, 4, 0, 11, 5, 2),
    (0, 15, 11, 8, 12, 9, 6, 3, 13, 1, 2, 4, 10, 7, 5, 14),
    (1, 15, 8, 3, 12, 0, 11, 6, 2, 5, 4, 10, 9, 14, 7, 13),
    (15, 5, 2, 11, 4, 10, 9, 12, 0, 3, 14, 8, 13, 6, 7, 1),
    (7, 2, 12, 5, 8, 4, 6, 11, 14, 9, 1, 15, 13, 3, 10, 0),
    (1, 13, 15, 0, 14, 8, 2, 11, 7, 4, 12, 10, 9, 3, 5, 6),
)
MASK = 0xffffffff


def rol32(x, count):
    return ((x << count) | (x >> (32 - count))) & MASK


def substitute(words, box):
    result = [0, 0, 0, 0]
    for position in range(32):
        index = sum(((word >> position) & 1) << bit
                    for bit, word in enumerate(words))
        value = SBOXES[box][index]
        for bit in range(4):
            result[bit] |= ((value >> bit) & 1) << position
    return result


def expand_key(key):
    if len(key) not in (16, 24, 32):
        raise ValueError("this reference supports 128, 192 and 256-bit keys")
    if len(key) < 32:
        key += b"\x01" + bytes(31 - len(key))
    words = list(struct.unpack("<8I", key))
    for i in range(132):
        words.append(rol32(words[i] ^ words[i + 3] ^ words[i + 5]
                           ^ words[i + 7] ^ 0x9e3779b9 ^ i, 11))
    return [substitute(words[8 + 4 * i:12 + 4 * i], (3 - i) % 8)
            for i in range(33)]


def linear_transform(words):
    x0, x1, x2, x3 = words
    x0, x2 = rol32(x0, 13), rol32(x2, 3)
    x1 ^= x0 ^ x2
    x3 ^= x2 ^ ((x0 << 3) & MASK)
    x1, x3 = rol32(x1, 1), rol32(x3, 7)
    x0 ^= x1 ^ x3
    x2 ^= x3 ^ ((x1 << 7) & MASK)
    return [rol32(x0, 5), x1, rol32(x2, 22), x3]


def encrypt_block(key, plaintext):
    if len(plaintext) != 16:
        raise ValueError("Serpent block size is 16 bytes")
    keys = expand_key(key)
    state = list(struct.unpack("<4I", plaintext))
    for round_index in range(32):
        state = substitute([a ^ b for a, b in zip(state, keys[round_index])],
                           round_index % 8)
        if round_index != 31:
            state = linear_transform(state)
    return struct.pack("<4I", *[a ^ b for a, b in zip(state, keys[32])])
