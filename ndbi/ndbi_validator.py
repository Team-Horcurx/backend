from pydantic import BaseModel, Field


class NdbiGridQuery(BaseModel):
    baseline_year: int = Field(...)
    comparison_year: int = Field(...)

    def validate_years(self):
        if self.comparison_year < self.baseline_year:
            raise ValueError("comparison_year must be >= baseline_year")
