import pydantic
import datetime

class Phoronix_Results (pydantic.BaseModel):
    Threads: int = pydantic.Field(gt=0)
    Average: float = pydantic.Field(gt=0, allow_inf_nan=False)
    Deviation: float = pydantic.Field(gt=0, allow_inf_nan=False)
    Start_Date: datetime.datetime
    End_Date: datetime.datetime

