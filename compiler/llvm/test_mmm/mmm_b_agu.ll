; AGU for array b
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

define dso_local void @agu_b() #0 {
; Loop level 1
%i1 = alloca i32, align 4
store i32 0, i32* %i1, align 4
br label %loop.header.1

loop.header.1:
%i1.load = load i32, i32* %i1, align 4
%i1.cmp = icmp slt i32 %i1.load, 32
br i1 %i1.cmp, label %loop.body.1, label %loop.exit.1

loop.body.1:
; Loop level 2
%i2 = alloca i32, align 4
store i32 0, i32* %i2, align 4
br label %loop.header.2

loop.header.2:
%i2.load = load i32, i32* %i2, align 4
%i2.cmp = icmp slt i32 %i2.load, 32
br i1 %i2.cmp, label %loop.body.2, label %loop.exit.2

loop.body.2:
; Access using %3
%3.val = load i32, i32* %3, align 4
; Access using %4
%4.val = load i32, i32* %4, align 4
%ptr_0 = getelementptr inbounds [32 x [32 x i32]], [32 x [32 x i32]]* @b, i32 0, i32 %3.val
%ptr_1 = getelementptr inbounds [32 x i32], [32 x i32]* %ptr_0, i32 0, i32 %4.val
%loaded.val = load i32, i32* %ptr_1, align 4

loop.exit.1:
%i1.next = add i32 %i1.load, 1
store i32 %i1.next, i32* %i1, align 4
br label %loop.header.1

loop.exit.2:
%i2.next = add i32 %i2.load, 1
store i32 %i2.next, i32* %i2, align 4
br label %loop.header.2
ret void
}

attributes #0 = { nounwind }