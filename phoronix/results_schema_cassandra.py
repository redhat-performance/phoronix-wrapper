import pydantic
import datetime

class Phoronix_Results (pydantic.BaseModel):
    Test: str
    Average: int = pydantic.Field(gt=0)
    Deviation: float = pydantic.Field(allow_inf_nan=False)
    Start_Date: datetime.datetime
    End_Date: datetime.datetime
