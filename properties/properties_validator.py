from pydantic import BaseModel, Field
from typing import Optional

STATUSES = ("pending", "verified", "underassessed", "false_positive", "already_assessed")


class VerifyBody(BaseModel):
    status: str = Field(...)
    notes: Optional[str] = ""
    updated_by: Optional[str] = "officer"

    def validate_status(self):
        if self.status not in STATUSES:
            raise ValueError(f"Invalid status '{self.status}'. Must be one of {STATUSES}")
