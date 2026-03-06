import pydantic
import datetime

from enum import Enum

class Benchmark(Enum):
    GET = "GET"
    SET = "SET"
    LPOP = "LPOP"
    SADD = "SADD"

class Phoronix_Results (pydantic.BaseModel):
    Test: Benchmark
    ParallelConnections: int = pydantic.Field(gt=0)
    Average: float = pydantic.Field(gt=0, allow_inf_nan=False)
    Deviation: float = pydantic.Field(allow_inf_nan=False)
    Start_Date: datetime.datetime
    End_Date: datetime.datetime

