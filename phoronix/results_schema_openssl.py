import pydantic
import datetime

from enum import Enum

class Benchmark(Enum):
    SHA256 = "SHA256"
    SHA512 = "SHA512"
    RSA4096 = "RSA4096"
    ChaCha20 = "ChaCha20"
    AES_128_GCM = "AES-128-GCM"
    AES_256_GCM = "AES-256-GCM"
    ChaCha20_Poly1305 = "ChaCha20-Poly1305"

class Phoronix_Results (pydantic.BaseModel):
    Algorithm: Benchmark
    BPS: float = pydantic.Field(gt=0, allow_inf_nan=False)
    Start_Date: datetime.datetime
    End_Date: datetime.datetime

