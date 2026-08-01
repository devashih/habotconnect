"""
Author: Devashish Sharma
Contact: devashishsharma2107@gmail.com
Student Onboarding Serializer — Schema Mapping & DCYN Validation (Task 3)

Design principle: every field carries an explicit, exhaustive validation
rule. There is no field that relies on a human reviewer's judgment to
decide whether a value "looks right." Each rule below maps 1:1 to a row
in the DCYN (Deconstructed Clean Yes/No) mapping table — see
dcyn-mapping.xlsx in this same folder.
"""

import re

from rest_framework import serializers


# Fixed choice list for learning_support_need. Using a closed enum instead
# of a free-text field is itself a Poka-Yoke decision: it makes an invalid
# category structurally impossible to submit, rather than relying on a
# human to catch a typo or an out-of-policy value after the fact.
LEARNING_SUPPORT_CHOICES = [
    ("dyslexia", "Dyslexia"),
    ("dyscalculia", "Dyscalculia"),
    ("dysgraphia", "Dysgraphia"),
    ("adhd", "Attention-Deficit/Hyperactivity Disorder"),
    ("autism_spectrum", "Autism Spectrum Support"),
    ("speech_language", "Speech and Language Support"),
    ("other_specified", "Other Specified Learning Difficulty"),
]

GUARDIAN_EMAIL_MAX_LENGTH = 254  # RFC 5321 maximum mailbox length
STUDENT_NAME_MAX_LENGTH = 120
TENANT_ID_PATTERN = re.compile(r"^[A-Z0-9]{6,12}$")


class StudentOnboardingSerializer(serializers.Serializer):
    """
    Deconstructs an incoming student-onboarding JSON payload into a
    binary Yes/No validation library. Every field either passes its
    exact rule (YES — record proceeds to D1_staged_enforced) or fails
    it (NO — record is rejected before it ever reaches BigQuery).
    """

    record_id = serializers.UUIDField(
        required=True,
        help_text="Unique submission identifier. Must be a valid UUID4 — "
        "no auto-incrementing integers, no human-readable slugs.",
    )

    tenant_id = serializers.RegexField(
        regex=TENANT_ID_PATTERN,
        required=True,
        help_text="Owning tenant/LSA-provider code. Exactly 6-12 uppercase "
        "alphanumeric characters. Drives BigQuery row-level security.",
    )

    student_full_name = serializers.CharField(
        required=True,
        allow_blank=False,
        max_length=STUDENT_NAME_MAX_LENGTH,
        min_length=2,
        trim_whitespace=True,
        help_text="Full legal name, no abbreviations or initials-only entries.",
    )

    guardian_email = serializers.EmailField(
        required=True,
        max_length=GUARDIAN_EMAIL_MAX_LENGTH,
        help_text="Verified guardian contact email. Standard email format "
        "validation via DRF's built-in EmailField.",
    )

    learning_support_need = serializers.ChoiceField(
        choices=LEARNING_SUPPORT_CHOICES,
        required=True,
        help_text="Must exactly match one of the seven fixed category codes. "
        "Any other value is rejected — no free-text substitution allowed.",
    )

    consent_confirmed = serializers.BooleanField(
        required=True,
        help_text="Binary Yes/No guardian consent flag. Must be explicitly "
        "True; a missing or False value halts the record immediately.",
    )

    def validate_consent_confirmed(self, value):
        """
        DCYN gate: consent is the single hard stop in this pipeline.
        No downstream field is even evaluated as 'complete' if this
        is False — the record is rejected outright, no exceptions,
        no manual override path.
        """
        if value is not True:
            raise serializers.ValidationError(
                "Guardian consent must be explicitly confirmed (True) before "
                "this record may proceed to the staged/enforced dataset."
            )
        return value

    def validate_tenant_id(self, value):
        """
        Defense in depth: RegexField already enforces the pattern, but this
        explicit re-check documents the rule in one place a reviewer can
        find without inspecting the field declaration above.
        """
        if not TENANT_ID_PATTERN.match(value):
            raise serializers.ValidationError(
                "tenant_id must be 6-12 uppercase alphanumeric characters "
                "with no exceptions."
            )
        return value
