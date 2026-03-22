"""Benchmark: Long Context Comprehension — MLX vs Claude Opus 4.6."""
import hashlib
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import timed_completion, score_exact, score_contains_all, write_results, print_test_result

_SYSTEM = "You are a careful reading assistant. Answer questions based solely on the provided text."

# ---------------------------------------------------------------------------
# Filler text generation
# ---------------------------------------------------------------------------

_SENTENCE_TEMPLATES = [
    # History
    (
        "The history of maritime navigation spans thousands of years, beginning with ancient "
        "Polynesian voyagers who crossed vast stretches of the Pacific using only the stars, "
        "wave patterns, and bird migration routes as guides. These early navigators possessed "
        "an intimate understanding of their environment that modern GPS technology has only "
        "recently begun to replicate in precision. The development of the magnetic compass in "
        "the twelfth century transformed ocean travel, enabling European explorers to venture "
        "far beyond sight of land with greater confidence. Subsequent innovations including the "
        "sextant, chronometer, and finally radio-based positioning systems each expanded "
        "humanity's ability to traverse the world's oceans safely and reliably."
    ),
    # Science
    (
        "Modern agricultural practices have evolved significantly over the past century, "
        "driven by the twin pressures of population growth and climate variability. The "
        "Green Revolution of the 1960s introduced high-yield crop varieties, synthetic "
        "fertilizers, and mechanized irrigation, dramatically increasing food production "
        "across Asia and Latin America. However, these gains came at environmental costs "
        "including soil degradation, groundwater depletion, and the collapse of biodiversity "
        "in intensively farmed regions. Contemporary precision agriculture seeks to address "
        "these shortcomings by using sensor arrays, satellite imaging, and machine learning "
        "algorithms to apply inputs only where and when they are needed, reducing waste while "
        "maintaining or improving yields per hectare."
    ),
    # Technology
    (
        "The development of computing hardware follows a trajectory shaped by both physical "
        "constraints and economic incentives. For five decades, transistor density on "
        "integrated circuits roughly doubled every two years in accordance with Moore's "
        "observation, enabling exponential improvements in processing speed and memory "
        "capacity. As feature sizes approached atomic dimensions, however, heat dissipation "
        "and quantum tunneling effects began to impose hard limits on further miniaturization. "
        "The industry responded by shifting toward multicore architectures, specialized "
        "accelerators for artificial intelligence workloads, and heterogeneous computing "
        "systems that combine different processor types on a single package. Three-dimensional "
        "chip stacking has emerged as another avenue for continued density improvements "
        "without requiring smaller transistors."
    ),
    # Geography
    (
        "The Atacama Desert, stretching along the western coast of South America between "
        "Chile and Peru, is one of the driest places on Earth, receiving less than one "
        "millimeter of precipitation annually in its core regions. Despite this extreme "
        "aridity, the Atacama supports a surprising variety of life adapted to its harsh "
        "conditions, including specialized cacti, salt-tolerant flowering plants, and "
        "populations of vicuña that graze on the sparse highland vegetation. The desert's "
        "exceptionally clear skies and high altitude have made it a premier location for "
        "astronomical observatories, with facilities including the Atacama Large Millimeter "
        "Array and the Very Large Telescope operated by the European Southern Observatory. "
        "Mining operations, particularly for copper and lithium, dominate the regional economy."
    ),
    # Economics
    (
        "The concept of comparative advantage, first articulated by David Ricardo in the "
        "early nineteenth century, provides the theoretical foundation for international "
        "trade. The principle holds that even if one nation can produce every good more "
        "efficiently than another, both countries benefit from specialization and exchange "
        "if each focuses on the goods it produces at the lowest opportunity cost. This "
        "insight underpins the case for free trade agreements, which seek to reduce tariffs "
        "and other barriers to cross-border commerce. Critics argue, however, that the "
        "static comparative advantage model fails to account for dynamic effects including "
        "learning-by-doing, infant industry development, and the uneven distribution of "
        "gains from trade within countries, where some workers and communities bear "
        "disproportionate adjustment costs."
    ),
    # Biology
    (
        "The immune system's ability to distinguish self from non-self is one of the most "
        "remarkable feats of biological information processing. T-lymphocytes undergo a "
        "stringent selection process in the thymus during development, where cells that "
        "react too strongly to the body's own proteins are eliminated by apoptosis, while "
        "those capable of recognizing foreign antigens presented by MHC molecules are "
        "retained and expanded. This central tolerance mechanism is supplemented by "
        "peripheral tolerance systems that prevent autoreactive cells from causing damage "
        "in the tissues. When these safeguards fail, autoimmune diseases can result, "
        "ranging from relatively mild conditions like Hashimoto's thyroiditis to severe "
        "systemic disorders such as lupus erythematosus, which can affect multiple organ "
        "systems simultaneously."
    ),
    # Architecture
    (
        "Gothic architecture emerged in twelfth-century France as a response to the "
        "structural and aesthetic limitations of Romanesque building. By using pointed "
        "arches, ribbed vaults, and flying buttresses in combination, Gothic builders "
        "were able to transfer the weight of stone walls and roofs outward and downward "
        "through slender supports, freeing the wall surfaces between to be filled with "
        "large stained-glass windows. The resulting interiors were flooded with colored "
        "light that contemporaries interpreted as a physical manifestation of divine "
        "illumination. The style spread rapidly across northern Europe and underwent "
        "numerous regional variations before giving way to Renaissance classicism in the "
        "fifteenth century, though it experienced a major revival in nineteenth-century "
        "Britain and North America, where architects applied Gothic forms to churches, "
        "universities, and government buildings."
    ),
    # Music
    (
        "The development of Western tonal harmony between roughly 1600 and 1900 created "
        "a sophisticated system for organizing pitches and chords that composers used to "
        "generate tension, expectation, and resolution over the course of a musical work. "
        "At its core, tonal harmony relies on a hierarchy of chords centered on the tonic, "
        "with the dominant chord a fifth above serving as the principal source of harmonic "
        "tension that resolves back to the tonic. Chromatic alterations, secondary "
        "dominants, and modulations to related keys allowed composers increasing expressive "
        "range within the tonal framework. By the late nineteenth century, composers "
        "including Wagner and Liszt were pushing these boundaries to their limits, using "
        "extended chromaticism and ambiguous harmonic progressions that eventually dissolved "
        "into the atonality of the early twentieth century."
    ),
    # Climate
    (
        "Ocean circulation patterns exert a profound influence on regional climates "
        "worldwide, redistributing heat from equatorial regions toward the poles and "
        "moderating temperature extremes along affected coastlines. The Atlantic Meridional "
        "Overturning Circulation, of which the Gulf Stream is the most familiar component, "
        "carries warm surface water northward and returns cold, dense deep water southward "
        "in a continuous conveyor belt. This system is responsible for the relatively mild "
        "winters experienced in Northwestern Europe compared to regions at similar latitudes "
        "on the North American continent. Climate scientists have expressed concern that "
        "increasing freshwater input from melting Greenland ice could disrupt this "
        "circulation by reducing the salinity and density of surface waters, potentially "
        "triggering abrupt regional cooling even as global average temperatures rise."
    ),
    # Psychology
    (
        "Research on human memory has revealed that recall is not a simple playback of "
        "stored experiences but rather a reconstructive process subject to systematic "
        "distortions. When we retrieve a memory, we reactivate distributed patterns of "
        "neural activity and then consolidate them again, a process during which new "
        "information can be integrated and errors introduced. Eyewitness testimony, once "
        "considered highly reliable by courts, has been substantially discredited through "
        "experimental studies showing that leading questions, post-event information, and "
        "the mere passage of time can alter witnesses' recollections in ways they cannot "
        "detect. These findings have led to reforms in investigative interview procedures "
        "designed to minimize contamination of witness memory before it can be recorded, "
        "including the use of open-ended questions and avoidance of confirmatory feedback."
    ),
]


def generate_filler_text(target_tokens: int, seed: int = 42) -> str:
    """Generate enough paragraphs to reach approximately target_tokens (1 token ~ 4 chars)."""
    rng = random.Random(seed)
    target_chars = target_tokens * 4
    paragraphs: list[str] = []
    total_chars = 0
    idx = 0
    while total_chars < target_chars:
        template = _SENTENCE_TEMPLATES[idx % len(_SENTENCE_TEMPLATES)]
        # Vary the paragraph slightly so repeated paragraphs are not identical
        variant_seed = seed + idx
        variant_hash = hashlib.md5(f"{variant_seed}".encode()).hexdigest()[:6]
        paragraph = f"[Section {idx + 1}] {template} (ref: {variant_hash})"
        paragraphs.append(paragraph)
        total_chars += len(paragraph) + 2  # +2 for the double newline separator
        idx += 1
    return "\n\n".join(paragraphs)


def _insert_needle(text: str, needle: str, position: float) -> str:
    """Insert needle_sentence into text at the given fractional position (0.0–1.0)."""
    insert_at = int(len(text) * position)
    # Snap to a paragraph boundary (double newline) near the target position
    nearby = text.rfind("\n\n", 0, insert_at)
    if nearby == -1:
        nearby = 0
    return text[:nearby] + "\n\n" + needle + "\n\n" + text[nearby:]


# ---------------------------------------------------------------------------
# Test 1: needle_2k
# ---------------------------------------------------------------------------
def test_needle_2k() -> dict:
    name = "needle_2k"
    needle = (
        "The secret project codename is Operation Thunderfish and it was launched on March 15, 2024."
    )
    filler = generate_filler_text(target_tokens=2000, seed=101)
    full_text = _insert_needle(filler, needle, position=0.5)
    question = "What is the secret project codename mentioned in the text?"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": f"{full_text}\n\n---\n\n{question}"},
            ],
            max_tokens=512,
        )
        score = score_exact("Thunderfish", content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 2: synthesis_8k
# ---------------------------------------------------------------------------
def test_synthesis_8k() -> dict:
    name = "synthesis_8k"
    needle_a = "Dr. Elena Vasquez discovered element Zephyrium in 2019."
    needle_b = "Zephyrium has an atomic weight of 312 and is highly unstable."
    needle_c = "The only known deposit of Zephyrium ore is in the Atacama Desert."
    filler = generate_filler_text(target_tokens=8000, seed=202)
    text = _insert_needle(filler, needle_a, position=0.25)
    text = _insert_needle(text, needle_b, position=0.50)
    text = _insert_needle(text, needle_c, position=0.75)
    question = (
        "Based on the text, where can Zephyrium ore be found, what is its atomic weight, "
        "and who discovered it?"
    )
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": f"{text}\n\n---\n\n{question}"},
            ],
            max_tokens=512,
        )
        score = score_contains_all(["Atacama", "312", "Vasquez"], content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 3: needle_16k
# ---------------------------------------------------------------------------
def test_needle_16k() -> dict:
    name = "needle_16k"
    needle = "The password to the vault is 'crystalline-aurora-7749'."
    filler = generate_filler_text(target_tokens=16000, seed=303)
    full_text = _insert_needle(filler, needle, position=0.5)
    question = "What is the password to the vault mentioned somewhere in the text?"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": f"{full_text}\n\n---\n\n{question}"},
            ],
            max_tokens=512,
        )
        score = score_exact("crystalline-aurora-7749", content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 4: multi_needle_32k
# ---------------------------------------------------------------------------
def test_multi_needle_32k() -> dict:
    name = "multi_needle_32k"
    needles = [
        (0.10, "Agent Alpha's real name is Marcus Chen."),
        (0.30, "Agent Beta's cover identity works at a bakery."),
        (0.50, "The drop point is at 47.3°N, 8.5°E (Zurich)."),
        (0.70, "The extraction date is December 14th."),
        (0.90, "The emergency frequency is 142.7 MHz."),
    ]
    filler = generate_filler_text(target_tokens=32000, seed=404)
    text = filler
    # Insert in reverse order of position so earlier insertions don't shift positions
    for position, needle in reversed(needles):
        text = _insert_needle(text, needle, position=position)
    question = "List all five spy-related facts mentioned throughout the text."
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": f"{text}\n\n---\n\n{question}"},
            ],
            max_tokens=512,
        )
        score = score_contains_all(["Marcus Chen", "bakery", "Zurich", "December 14", "142.7"], content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    print("=== Long Context Comprehension Benchmark ===")
    tests = [
        test_needle_2k,
        test_synthesis_8k,
        test_needle_16k,
        test_multi_needle_32k,
    ]

    results: list[dict] = []
    for fn in tests:
        result = fn()
        results.append(result)

    write_results("long_context", results)

    total = len(results)
    mean_score = sum(r["score"] for r in results) / max(total, 1)
    passed = sum(1 for r in results if r["score"] >= 0.8)
    print(f"\n  Category summary: {passed}/{total} passed  |  mean score: {mean_score:.2f}")


if __name__ == "__main__":
    main()
