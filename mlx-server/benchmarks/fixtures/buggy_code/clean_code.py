"""String utility functions — correctly implemented."""
from collections import Counter


def is_anagram(s1: str, s2: str) -> bool:
    """Check if two strings are anagrams (case-insensitive)."""
    return Counter(s1.lower().replace(" ", "")) == Counter(s2.lower().replace(" ", ""))


def longest_common_prefix(strings: list[str]) -> str:
    """Find longest common prefix among a list of strings."""
    if not strings:
        return ""
    prefix = strings[0]
    for s in strings[1:]:
        while not s.startswith(prefix):
            prefix = prefix[:-1]
            if not prefix:
                return ""
    return prefix


def caesar_cipher(text: str, shift: int) -> str:
    """Apply Caesar cipher with given shift."""
    result = []
    for char in text:
        if char.isalpha():
            base = ord('A') if char.isupper() else ord('a')
            shifted = (ord(char) - base + shift) % 26 + base
            result.append(chr(shifted))
        else:
            result.append(char)
    return ''.join(result)


def word_frequency(text: str) -> dict[str, int]:
    """Count word frequencies in text (case-insensitive)."""
    words = text.lower().split()
    return dict(Counter(words))
