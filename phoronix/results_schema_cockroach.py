import pydantic
import datetime

class Phoronix_Results (pydantic.BaseModel):
    Workload: str
    Concurrency: int = pydantic.Field(gt=0)
    Average: float = pydantic.Field(allow_inf_nan=False)
    Deviation: float = pydantic.Field(allow_inf_nan=False)
    Start_Date: datetime.datetime
    End_Date: datetime.datetime
