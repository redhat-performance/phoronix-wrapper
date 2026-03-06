import pydantic
import datetime

from enum import Enum

class Benchmark(Enum):
    Hash = "Hash"
    MMAP = "MMAP"
    NUMA = "NUMA"
    Pipe = "Pipe"
    Poll = "Poll"
    Zlib = "Zlib"
    Futex = "Futex"
    MEMFD = "MEMFD"
    Mutex = "Mutex"
    Atomic = "Atomic"
    Crypto = "Crypto"
    Malloc = "Malloc"
    Cloning = "Cloning"
    Forking = "Forking"
    Pthread = "Pthread"
    AVL_Tree = "AVL Tree"
    SENDFILE = "SENDFILE"
    CPU_Cache = "CPU Cache"
    CPU_Stress = "CPU Stress"
    Power_Math = "Power Math"
    Semaphores = "Semaphores"
    Matrix_Math = "Matrix Math"
    Vector_Math = "Vector Math"
    AVX_512_VNNI = "AVX-512 VNNI"
    Integer_Math = "Integer Math"
    Function_Call = "Function Call"
    x86_64_RdRand = "x86_64 RdRand"
    Floating_Point = "Floating Point"
    Matrix_3D_Math = "Matrix 3D Math"
    Memory_Copying = "Memory Copying"
    Vector_Shuffle = "Vector Shuffle"
    Mixed_Scheduler = "Mixed Scheduler"
    Socket_Activity = "Socket Activity"
    Exponential_Math = "Exponential Math"
    Jpeg_Compression = "Jpeg Compression"
    Logarithmic_Math = "Logarithmic Math"
    Wide_Vector_Math = "Wide Vector Math"
    Context_Switching = "Context Switching"
    Fractal_Generator = "Fractal Generator"
    Radix_String_Sort = "Radix String Sort"
    Fused_Multiply_Add = "Fused Multiply-Add"
    Trigonometric_Math = "Trigonometric Math"
    Bitonic_Integer_Sort = "Bitonic Integer Sort"
    Vector_Floating_Point = "Vector Floating Point"
    Bessel_Math_Operations = "Bessel Math Operations"
    Integer_Bit_Operations = "Integer Bit Operations"
    Glibc_C_String_Functions = "Glibc C String Functions"
    Glibc_Qsort_Data_Sorting = "Glibc Qsort Data Sorting"
    System_V_Message_Passing = "System V Message Passing"
    POSIX_Regular_Expressions = "POSIX Regular Expressions"
    Hyperbolic_Trigonometric_Math = "Hyperbolic Trigonometric Math"

class Phoronix_Results (pydantic.BaseModel):
    Test: Benchmark
    Average: float = pydantic.Field(gt=0, allow_inf_nan=False)
    Deviation: float = pydantic.Field(allow_inf_nan=False)
    Start_Date: datetime.datetime
    End_Date: datetime.datetime

