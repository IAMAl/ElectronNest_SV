# CGRA Compiler for Modern Computing
## Overview

This project introduces a compiler targeting Coarse-Grained Reconfigurable Array (CGRA) architectures with on-chip memories. Our approach focuses on generating efficient address generation programs for array operations in loop sections, a critical aspect in modern data-intensive computing.

## Background: Challenges in Memory Access

Modern processors face significant challenges with memory access patterns, particularly in data-intensive loop operations. Traditional cache-based approaches struggle with predictable but complex array access patterns common in scientific computing and matrix operations. While various optimization techniques exist, they often require complex hardware support and sophisticated analysis.

## Our Solution: Address Generation Focused CGRA Compiler

Our proposed CGRA compiler takes a fundamentally different approach by focusing on address generation for on-chip memories. Rather than fighting memory dependencies, we embrace them by analyzing loop sections in programs and their array access patterns. The compiler extracts data dependencies from LLVM IR and maps them to the CGRA structure, enabling efficient memory access pattern generation.

The compiler's data flow based operation provides natural handling of nested loop structures while managing index updates and initialization. This approach allows for coordinated access across multiple arrays, essential for complex operations like matrix multiplication. By working with standard LLVM IR input, the compiler maintains compatibility with existing development tools while providing specialized optimization for CGRA architectures.

## Advantages and Implementation

Our approach significantly simplifies both hardware requirements and programmer effort while maintaining high performance through efficient memory access patterns. The compiler automatically handles the complexity of memory access optimization, allowing developers to focus on algorithm implementation rather than architectural details. This combination of ease of use and efficient execution makes our CGRA compiler a practical solution for modern computing challenges.

The compiler achieves these benefits by focusing on the fundamental patterns of array access in loop structures, a common requirement in scientific and data processing applications. By generating optimized address generation unit programs, it enables efficient use of on-chip memories while maintaining program correctness. This approach provides a balanced solution that addresses both performance requirements and implementation practicality.